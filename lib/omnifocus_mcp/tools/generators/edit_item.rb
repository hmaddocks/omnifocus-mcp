# frozen_string_literal: true

require_relative "../../infrastructure/apple_script"
require_relative "../../infrastructure/apple_script_date_builder"
require_relative "../../parsers/apple_script_envelope"
require_relative "../../utils/blank"
require_relative "../../result"
require_relative "../../infrastructure/script_runner"
require_relative "../params"

module OmnifocusMcp
  module Tools
    module Generators
      # Edit a task or project in OmniFocus.
      #
      # Returns an {OmnifocusMcp::Result} whose +ok+ payload is an {Edited} carrying the
      # item's id, name, and a +changed_properties+ string (comma-separated
      # property names that the script reported as modified).
      class EditItem
        # Task statuses: 'incomplete' | 'completed' | 'dropped' | 'skipped'
        # Project statuses: 'active' | 'completed' | 'dropped' | 'onHold'

        Edited = Data.define(:id, :name, :changed_properties)

        DATE_FIELDS = [
          [:new_due_date, "due date"],
          [:new_defer_date, "defer date"],
          [:new_planned_date, "planned date"]
        ].freeze
        private_constant :DATE_FIELDS

        PROJECT_STATUS_MAP = {
          "active" => "active status",
          "completed" => "done status",
          "dropped" => "dropped status"
        }.freeze
        private_constant :PROJECT_STATUS_MAP

        # Generate pure AppleScript for item editing. Dates are constructed
        # outside the `tell` block then referenced from within.
        class << self
          def generate_apple_script(params)
            params = Params::McpBoundary.coerce(Params::EditItemParams, params)
            return missing_identifier_error if Utils::Blank.blank?(params.id, params.name)

            id = Infrastructure::AppleScript.escape(params.id.to_s)
            name = Infrastructure::AppleScript.escape(params.name.to_s)
            item_type = params.item_type.to_s

            date_pre_scripts, date_assignments = collect_date_assignments(params)

            [
              date_pre_scripts.join("\n\n"),
              Infrastructure::AppleScript.tell_document(document_body(item_type, id, name, params, date_assignments))
            ].reject(&:empty?).join("\n\n")
          end

          # Run the generated AppleScript against OmniFocus and parse the JSON result.
          def call(params)
            require_relative "../operations/edit_item"

            Operations::EditItem.call(params)
          end

          private

          def run_script(script)
            stdout, stderr, status = Infrastructure::ScriptRunner.execute_applescript(script)

            OmnifocusMcp.logger.warn("[edit_item] AppleScript stderr: #{stderr}") if stderr && !stderr.empty?
            return OmnifocusMcp::Result.error(applescript_run_failure(stderr:, status:)) unless status.success?

            parse_result(stdout)
          end

          def parse_result(stdout)
            Parsers::AppleScriptEnvelope.parse(stdout:, default_error: "Unknown error in edit_item") do |hash|
              OmnifocusMcp::Result.ok(
                Edited.new(
                  id: hash["id"],
                  name: hash["name"],
                  changed_properties: hash["changedProperties"]
                )
              )
            end
          end

          def applescript_run_failure(stderr:, status:)
            exit_code = status.respond_to?(:exitstatus) ? status.exitstatus : status
            message = "osascript failed (exit #{exit_code})"
            message += ": #{stderr.strip}" unless stderr.nil? || stderr.empty?
            message
          end

          def missing_identifier_error
            %(return "{\\"success\\":false,\\"error\\":\\"Either id or name must be provided\\"}")
          end

          # Walk the three date params, returning [pre_scripts, assignments].
          # `assignments` is a Hash from property name to AppleScript line that
          # assigns the prepared date variable to that property.
          def collect_date_assignments(params)
            pre_scripts = []
            assignments = {}

            DATE_FIELDS.each do |param_key, property_name|
              parts = Infrastructure::AppleScriptDateBuilder.generate_date_assignment(
                "foundItem", property_name, params.public_send(param_key)
              )
              next if parts.nil?

              pre_scripts << parts.pre_script unless Utils::Blank.blank?(parts.pre_script)
              assignments[property_name] = parts.assignment_script
            end

            [pre_scripts, assignments]
          end

          # The interior of the `tell front document` block.
          def document_body(item_type, id, name, params, date_assignments)
            <<~APPLESCRIPT.chomp
              -- Find the item to edit
              #{Infrastructure::AppleScript.find_item(var: "foundItem", item_type: item_type, id: id, name: name)}
              -- If we found the item, edit it
              if foundItem is not missing value then
              #{Infrastructure::AppleScript.indent(text: item_found_body(item_type, params, date_assignments).chomp, prefix: "  ")}
              else
                return "{\\"success\\":false,\\"error\\":\\"Item not found\\"}"
              end if
            APPLESCRIPT
          end

          # Everything inside the `if foundItem is not missing value then`
          # branch: collect each property update as a string, drop nils,
          # finish with the changed-properties join and success envelope.
          def item_found_body(item_type, params, date_assignments)
            steps = [
              "set itemName to name of foundItem",
              "set itemId to id of foundItem as string",
              "set changedProperties to {}"
            ]
            steps.concat(property_update_steps(item_type, params, date_assignments).compact)
            steps << finalize_and_return

            steps.join("\n\n")
          end

          def property_update_steps(item_type, params, date_assignments)
            [
              update_string_property("name", params, :new_name),
              update_string_property("note", params, :new_note),
              update_date_step("due date", date_assignments["due date"]),
              update_date_step("defer date", date_assignments["defer date"]),
              update_date_step("planned date", date_assignments["planned date"]),
              update_literal_property("flagged", params, :new_flagged),
              update_literal_property("estimated minutes", params, :new_estimated_minutes),
              *task_or_project_steps(item_type, params)
            ]
          end

          def task_or_project_steps(item_type, params)
            case item_type
            when "task"
              [
                apply_task_status(params),
                apply_tag_operations(params),
                apply_new_project_name(params)
              ]
            when "project"
              [
                apply_sequential(params),
                apply_project_status(params),
                apply_new_folder(params)
              ]
            else
              []
            end
          end

          # `set foo of foundItem to "escaped string"` + changedProperties bump.
          def update_string_property(label, params, key)
            return nil unless param_provided?(params, key)

            value = Infrastructure::AppleScript.escape(params.public_send(key).to_s)
            <<~APPLESCRIPT.chomp
              -- Update #{label}
              set #{label} of foundItem to "#{value}"
              set end of changedProperties to "#{label}"
            APPLESCRIPT
          end

          # `set foo of foundItem to <raw value>` + changedProperties bump.
          # For booleans / numbers (no AppleScript quotes).
          def update_literal_property(label, params, key)
            return nil unless param_provided?(params, key)

            <<~APPLESCRIPT.chomp
              -- Update #{label}
              set #{label} of foundItem to #{params.public_send(key)}
              set end of changedProperties to "#{label}"
            APPLESCRIPT
          end

          def update_date_step(label, assignment_script)
            return nil unless assignment_script

            <<~APPLESCRIPT.chomp
              -- Update #{label}
              #{assignment_script}
              set end of changedProperties to "#{label}"
            APPLESCRIPT
          end

          def finalize_and_return
            <<~APPLESCRIPT.chomp
              -- Prepare the changed properties as a string
              set changedPropsText to ""
              repeat with i from 1 to count of changedProperties
                set changedPropsText to changedPropsText & item i of changedProperties
                if i < count of changedProperties then
                  set changedPropsText to changedPropsText & ", "
                end if
              end repeat

              -- Return success with details
              return "{\\"success\\":true,\\"id\\":\\"" & itemId & "\\",\\"name\\":\\"" & itemName & "\\",\\"changedProperties\\":\\"" & changedPropsText & "\\"}"
            APPLESCRIPT
          end

          def apply_task_status(params)
            return nil unless param_provided?(params, :new_status)

            case params.new_status.to_s
            when "completed" then task_status_completed
            when "dropped" then task_status_dropped
            when "skipped" then task_status_skipped
            when "incomplete" then task_status_incomplete
            end
          end

          def task_status_completed
            <<~APPLESCRIPT.chomp
              -- Mark task as completed (works reliably for all task types including inbox tasks)
              mark complete foundItem
              set end of changedProperties to "status (completed)"
            APPLESCRIPT
          end

          def task_status_dropped
            <<~APPLESCRIPT.chomp
              -- Mark task as dropped
              mark dropped foundItem
              set end of changedProperties to "status (dropped)"
            APPLESCRIPT
          end

          def task_status_incomplete
            <<~APPLESCRIPT.chomp
              -- Mark task as incomplete
              mark incomplete foundItem
              set end of changedProperties to "status (incomplete)"
            APPLESCRIPT
          end

          def task_status_skipped
            <<~APPLESCRIPT.chomp
              -- Skip repeating task: complete it to fire the next repeat, then drop the completed instance
              if repetition rule of foundItem is missing value then
                return "{\\"success\\":false,\\"error\\":\\"Cannot skip a non-repeating task. The task must have a repetition rule.\\"}"
              end if

              -- Store the ID of the current instance before completing
              set skippedTaskId to id of foundItem as string

              -- Complete the task to trigger the next repetition
              mark complete foundItem

              -- Now find and drop the completed instance by its original ID
              try
                set completedTask to first flattened task whose id is skippedTaskId
                set dropped of completedTask to true
                set end of changedProperties to "status (skipped)"
              on error
                -- The completed instance may have moved; still report success since repeat was triggered
                set end of changedProperties to "status (skipped - completed instance not found to drop)"
              end try
            APPLESCRIPT
          end

          def apply_tag_operations(params)
            return tag_replace_block(params.replace_tags) if non_empty?(params.replace_tags)

            blocks = [
              non_empty?(params.add_tags) ? tag_add_block(params.add_tags) : nil,
              non_empty?(params.remove_tags) ? tag_remove_block(params.remove_tags) : nil
            ].compact

            blocks.empty? ? nil : blocks.join("\n\n")
          end

          def non_empty?(value) = value && !value.empty?

          # rubocop:disable Metrics/MethodLength
          def tag_replace_block(tags)
            tags_list = tags.map { |t| %("#{Infrastructure::AppleScript.escape(t.to_s)}") }.join(", ")
            <<~APPLESCRIPT.chomp
              -- Replace all tags
              set tagNames to {#{tags_list}}
              set existingTags to tags of foundItem

              -- First clear all existing tags
              repeat with existingTag in existingTags
                remove existingTag from tags of foundItem
              end repeat

              -- Then add new tags
              repeat with tagName in tagNames
                set tagObj to missing value
                try
                  set tagObj to first flattened tag where name = (tagName as string)
                on error
                  -- Tag doesn't exist, create it
                  set tagObj to make new tag with properties {name:(tagName as string)}
                end try
                if tagObj is not missing value then
                  add tagObj to tags of foundItem
                end if
              end repeat
              set end of changedProperties to "tags (replaced)"
            APPLESCRIPT
          end
          # rubocop:enable Metrics/MethodLength

          def tag_add_block(tags)
            tags_list = tags.map { |t| %("#{Infrastructure::AppleScript.escape(t.to_s)}") }.join(", ")
            <<~APPLESCRIPT.chomp
              -- Add tags
              set tagNames to {#{tags_list}}
              repeat with tagName in tagNames
                set tagObj to missing value
                try
                  set tagObj to first flattened tag where name = (tagName as string)
                on error
                  -- Tag doesn't exist, create it
                  set tagObj to make new tag with properties {name:(tagName as string)}
                end try
                if tagObj is not missing value then
                  add tagObj to tags of foundItem
                end if
              end repeat
              set end of changedProperties to "tags (added)"
            APPLESCRIPT
          end

          def tag_remove_block(tags)
            tags_list = tags.map { |t| %("#{Infrastructure::AppleScript.escape(t.to_s)}") }.join(", ")
            <<~APPLESCRIPT.chomp
              -- Remove tags
              set tagNames to {#{tags_list}}
              repeat with tagName in tagNames
                try
                  set tagObj to first flattened tag where name = (tagName as string)
                  remove tagObj from tags of foundItem
                end try
              end repeat
              set end of changedProperties to "tags (removed)"
            APPLESCRIPT
          end

          def apply_new_project_name(params)
            return nil unless param_provided?(params, :new_project_name)

            project_name = params.new_project_name.to_s

            if project_name.empty? || project_name.downcase == "inbox"
              move_task_to_inbox_block
            else
              move_task_to_project_block(project_name)
            end
          end

          def move_task_to_inbox_block
            <<~APPLESCRIPT.chomp
              -- Move task to inbox by clearing its assigned container
              set assigned container of foundItem to missing value
              set end of changedProperties to "project (moved to inbox)"
            APPLESCRIPT
          end

          def move_task_to_project_block(project_name)
            escaped = Infrastructure::AppleScript.escape(project_name)
            error_json = %({\\"success\\":false,\\"error\\":\\"Project not found: #{escaped}\\"})
            project_lookup = Infrastructure::AppleScript.generate_project_lookup_script(
              raw_project_path: project_name, var_name: "destProject", error_return_json: error_json
            )
            <<~APPLESCRIPT.chomp
              -- Find the destination project (supports folder paths like "Work/My Project")
              #{project_lookup}

              move foundItem to end of tasks of destProject
              set end of changedProperties to "project (moved to #{escaped})"
            APPLESCRIPT
          end

          def apply_sequential(params)
            return nil unless param_provided?(params, :new_sequential)

            <<~APPLESCRIPT.chomp
              -- Update sequential status
              set sequential of foundItem to #{params.new_sequential}
              set end of changedProperties to "sequential"
            APPLESCRIPT
          end

          def apply_project_status(params)
            return nil unless param_provided?(params, :new_project_status)

            status_value = PROJECT_STATUS_MAP.fetch(params.new_project_status.to_s, "on hold status")

            <<~APPLESCRIPT.chomp
              -- Update project status
              set status of foundItem to #{status_value}
              set end of changedProperties to "status"
            APPLESCRIPT
          end

          def apply_new_folder(params)
            return nil unless param_provided?(params, :new_folder_name)
            return nil if Utils::Blank.blank?(params.new_folder_name)

            folder_name = params.new_folder_name.to_s
            escaped = Infrastructure::AppleScript.escape(folder_name)
            error_json = %({\\"success\\":false,\\"error\\":\\"Folder not found: #{escaped}\\"})
            folder_lookup = Infrastructure::AppleScript.generate_folder_lookup_script(
              raw_folder_path: folder_name, var_name: "destFolder", error_return_json: error_json
            )

            <<~APPLESCRIPT.chomp
              -- Find the destination folder
              #{folder_lookup}

              -- Move project to the folder
              move {foundItem} to end of projects of destFolder
              set end of changedProperties to "folder"
            APPLESCRIPT
          end

          def param_provided?(params, key)
            !params.public_send(key).nil?
          end
        end
      end
    end
  end
end
