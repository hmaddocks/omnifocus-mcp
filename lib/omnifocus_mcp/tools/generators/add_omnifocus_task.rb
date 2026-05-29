# frozen_string_literal: true

require "securerandom"

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
      # Add a task to OmniFocus.
      #
      # Returns an {OmnifocusMcp::Result} whose +ok+ payload is a {Created}
      # carrying the new task's id and placement.
      class AddOmniFocusTask
        Created = Data.define(:task_id, :placement)

        # Generate pure AppleScript for task creation.
        # @param params [Tools::Params::AddTaskParams]
        class << self
          def generate_apple_script(params)
            params = Params::McpBoundary.coerce(Params::AddTaskParams, params)
            fields = extract_fields(params)
            date_pre_script, date_vars = build_date_pre_scripts(params)

            body = document_body(fields:, date_vars:)

            preamble = date_pre_script.empty? ? "" : "#{date_pre_script}\n"
            preamble + Infrastructure::AppleScript.tell_document(body)
          end

          # Run the generated AppleScript against OmniFocus and parse the JSON result.
          # @param params [Tools::Params::AddTaskParams]
          def call(params)
            require_relative "../operations/add_omnifocus_task"

            Operations::AddOmniFocusTask.call(params)
          end

          # Combine multiple independent tasks into one osascript invocation.
          def generate_bulk_apple_script(params_list)
            pre_scripts = params_list.flat_map { |params| date_pre_script_for(params) }

            bodies = params_list.map { |params| bulk_item_body(params) }
            preamble = pre_scripts.join("\n\n")
            preamble += "\n\n" unless preamble.empty?
            preamble += <<~APPLESCRIPT
              set bulkTaskIds to {}
              set bulkPlacements to {}
            APPLESCRIPT

            inner = (bodies + [bulk_finalize_return]).join("\n\n")
            preamble + "\n\n#{Infrastructure::AppleScript.tell_document(inner)}"
          end

          private

          def parse_result(stdout)
            Parsers::AppleScriptEnvelope.parse(stdout:, default_error: "Unknown error in add_omnifocus_task") do |hash|
              OmnifocusMcp::Result.ok(Created.new(task_id: hash["taskId"], placement: hash["placement"]))
            end
          end

          def applescript_run_failure(stderr:, status:)
            exit_code = status.respond_to?(:exitstatus) ? status.exitstatus : status
            message = "osascript failed (exit #{exit_code})"
            message += ": #{stderr.strip}" unless stderr.nil? || stderr.empty?
            message
          end

          # Collect and escape the input params once. Returns a Hash with
          # plain Ruby values + AppleScript-escaped strings.
          def extract_fields(params)
            {
              name: Infrastructure::AppleScript.escape(params.name.to_s),
              note: Infrastructure::AppleScript.escape(params.note.to_s),
              project_name: Infrastructure::AppleScript.escape(params.project_name.to_s),
              parent_task_id: Infrastructure::AppleScript.escape(params.parent_task_id.to_s),
              parent_task_name: Infrastructure::AppleScript.escape(params.parent_task_name.to_s),
              flagged: params.flagged == true,
              estimated_minutes: estimated_minutes(params.estimated_minutes),
              tags: params.tags || []
            }
          end

          def estimated_minutes(value)
            return "" if Utils::Blank.blank?(value)

            value.to_s
          end

          # Build the AppleScript that initialises each date variable
          # *outside* the tell block. Returns [pre_script, vars_hash].
          def build_date_pre_scripts(params)
            assignments = {}
            pre_scripts = []

            %i[due_date defer_date planned_date].each do |key|
              value = params.public_send(key)
              next if Utils::Blank.blank?(value)

              iso = value.to_s

              var = "#{key.to_s.split("_").first}Date#{random_suffix}"
              pre_scripts << Infrastructure::AppleScriptDateBuilder.create_date_outside_tell_block(iso, var)
              assignments[key] = var
            end

            [pre_scripts.join("\n\n"), assignments]
          end

          def document_body(fields:, date_vars:, finalize: :single)
            [
              "-- Resolve parent task if provided",
              "set newTask to missing value",
              "set parentTask to missing value",
              %(set placement to ""),
              "",
              parent_task_resolution(fields),
              "",
              task_creation(fields),
              "",
              property_setters(fields:, date_vars:),
              "",
              placement_derivation(fields[:project_name]),
              "",
              "-- Get the task ID",
              "set taskId to id of newTask as string",
              tag_assignments_block(fields[:tags]),
              finalize == :bulk ? bulk_record_result : success_return(fields[:name])
            ].compact.join("\n")
          end

          # AppleScript fragment appended after each task in a bulk add.
          def bulk_record_result
            <<~APPLESCRIPT.chomp
              set end of bulkTaskIds to taskId
              set end of bulkPlacements to placement
            APPLESCRIPT
          end

          # Build tell-block body for one task inside a bulk script.
          def date_pre_script_for(params)
            params = Params::McpBoundary.coerce(Params::AddTaskParams, params)
            pre, = build_date_pre_scripts(params)
            pre.empty? ? [] : [pre]
          end

          def bulk_item_body(params)
            params = Params::McpBoundary.coerce(Params::AddTaskParams, params)
            fields = extract_fields(params)
            _pre, date_vars = build_date_pre_scripts(params)
            document_body(fields:, date_vars:, finalize: :bulk)
          end

          def bulk_finalize_return
            <<~APPLESCRIPT.chomp
              -- Build JSON array of {taskId, placement} objects
              set jsonItems to "["
              repeat with i from 1 to count of bulkTaskIds
                set tid to item i of bulkTaskIds
                set plc to item i of bulkPlacements
                set jsonItems to jsonItems & "{\\"taskId\\":\\"" & tid & "\\",\\"placement\\":\\"" & plc & "\\"}"
                if i < count of bulkTaskIds then set jsonItems to jsonItems & ","
              end repeat
              set jsonItems to jsonItems & "]"
              return "{\\"success\\":true,\\"items\\":" & jsonItems & "}"
            APPLESCRIPT
          end

          def success_return(escaped_name)
            payload = [
              %(\\"taskId\\":\\"" & taskId & "\\"),
              %(\\"name\\":\\"#{escaped_name}\\"),
              %(\\"placement\\":\\"" & placement & "\\")
            ].join(",")
            %(return "{\\"success\\":true,#{payload}}")
          end

          # Two-step parent task lookup: first by explicit id (if given),
          # then by name (if no id resolved). When a project is also given,
          # the parent must live in that project.
          def parent_task_resolution(fields)
            <<~APPLESCRIPT.chomp
              #{parent_lookup_by_id(fields)}

              #{parent_lookup_by_name(fields)}
            APPLESCRIPT
          end

          def parent_lookup_by_id(fields)
            <<~APPLESCRIPT.chomp
              if "#{fields[:parent_task_id]}" is not "" then
                try
                  set parentTask to first flattened task where id = "#{fields[:parent_task_id]}"
                end try
                if parentTask is missing value then
                  try
                    set parentTask to first inbox task where id = "#{fields[:parent_task_id]}"
                  end try
                end if
                -- If projectName provided, ensure parent is within that project
                if parentTask is not missing value and "#{fields[:project_name]}" is not "" then
                  try
                    set pproj to containing project of parentTask
                    if pproj is missing value or name of pproj is not "#{fields[:project_name]}" then set parentTask to missing value
                  end try
                end if
              end if
            APPLESCRIPT
          end

          # rubocop:disable Metrics/MethodLength
          def parent_lookup_by_name(fields)
            <<~APPLESCRIPT.chomp
              if parentTask is missing value and "#{fields[:parent_task_name]}" is not "" then
                if "#{fields[:project_name]}" is not "" then
                  -- Find by name but constrain to the specified project
                  try
                    set parentTask to first flattened task where name = "#{fields[:parent_task_name]}"
                  end try
                  if parentTask is not missing value then
                    try
                      set pproj to containing project of parentTask
                      if pproj is missing value or name of pproj is not "#{fields[:project_name]}" then set parentTask to missing value
                    end try
                  end if
                else
                  -- No project specified; allow global or inbox match by name
                  try
                    set parentTask to first flattened task where name = "#{fields[:parent_task_name]}"
                  end try
                  if parentTask is missing value then
                    try
                      set parentTask to first inbox task where name = "#{fields[:parent_task_name]}"
                    end try
                  end if
                end if
              end if
            APPLESCRIPT
          end
          # rubocop:enable Metrics/MethodLength

          # Pick the container: explicit parent, project root, or inbox.
          def task_creation(fields)
            <<~APPLESCRIPT.chomp
              if parentTask is not missing value then
                -- Create task under parent task
                set newTask to make new task with properties {name:"#{fields[:name]}"} at end of tasks of parentTask
              else if "#{fields[:project_name]}" is not "" then
                -- Create under specified project
                try
                  set theProject to first flattened project where name = "#{fields[:project_name]}"
                  set newTask to make new task with properties {name:"#{fields[:name]}"} at end of tasks of theProject
                on error
                  return "{\\"success\\":false,\\"error\\":\\"Project not found: #{fields[:project_name]}\\"}"
                end try
              else
                -- Fallback to inbox
                set newTask to make new inbox task with properties {name:"#{fields[:name]}"}
              end if
            APPLESCRIPT
          end

          def property_setters(fields:, date_vars:)
            lines = ["-- Set task properties"]
            lines << %(set note of newTask to "#{fields[:note]}") unless fields[:note].empty?
            %i[due_date defer_date planned_date].each do |key|
              next unless date_vars[key]

              lines.concat(date_setter(key, date_vars[key]))
            end
            lines << "set flagged of newTask to true" if fields[:flagged]
            minutes = fields[:estimated_minutes]
            lines << "set estimated minutes of newTask to #{minutes}" unless minutes.empty?
            lines.join("\n")
          end

          def date_setter(key, value)
            label = key.to_s.split("_").first
            ["-- Set #{label} date", "set #{label} date of newTask to #{value}"]
          end

          # rubocop:disable Metrics/MethodLength
          def placement_derivation(project_name)
            <<~APPLESCRIPT.chomp
              -- Derive placement from container; distinguish real parent vs project root task
              try
                set placement to "inbox"
                set ctr to container of newTask
                set cclass to class of ctr as string
                set ctrId to id of ctr as string
                if cclass is "project" then
                  set placement to "project"
                else if cclass is "task" then
                  if parentTask is not missing value then
                    set parentId to id of parentTask as string
                    if ctrId is equal to parentId then
                      set placement to "parent"
                    else
                      -- Likely the project's root task; treat as project
                      set placement to "project"
                    end if
                  else
                    -- No explicit parent requested; container is root task -> treat as project
                    set placement to "project"
                  end if
                else
                  set placement to "inbox"
                end if
              on error
                -- If container access fails (e.g., inbox), default based on projectName
                if "#{project_name}" is not "" then
                  set placement to "project"
                else
                  set placement to "inbox"
                end if
              end try
            APPLESCRIPT
          end
          # rubocop:enable Metrics/MethodLength

          def tag_assignments_block(tags)
            return nil if tags.empty?

            blocks = tags.map do |tag|
              Infrastructure::AppleScript.tag_assignment(
                item_var: "newTask",
                tag_name: Infrastructure::AppleScript.escape(tag.to_s)
              )
            end

            "\n-- Add tags if provided\n#{blocks.join("\n")}"
          end

          def random_suffix
            SecureRandom.hex(5)
          end
        end
      end
    end
  end
end
