# frozen_string_literal: true

require "securerandom"

require_relative "../../infrastructure/apple_script"
require_relative "../../infrastructure/apple_script_date_builder"
require_relative "../../utils/blank"
require_relative "../params"

module OmnifocusMcp
  module Tools
    module Generators
      class AddProject
        class << self
          def generate_apple_script(params = nil, **kwargs)
            merge_params(params, kwargs).then do |params|
              params = Params::McpBoundary.coerce(Params::AddProjectParams, params)
              fields = extract_fields(params)
              date_pre_script, date_vars = build_date_pre_scripts(params)
              body = document_body(fields:, date_vars:)
              preamble = date_pre_script.empty? ? "" : "#{date_pre_script}\n"

              preamble + Infrastructure::AppleScript.tell_document(body)
            end
          end

          private

          def merge_params(params, kwargs)
            return params || {} if kwargs.empty?

            base = params.respond_to?(:to_h) ? params.to_h : params || {}
            base.merge(kwargs)
          end

          def extract_fields(params)
            {
              name: Infrastructure::AppleScript.escape(params.name.to_s),
              note: Infrastructure::AppleScript.escape(params.note.to_s),
              folder_name: params.folder_name.to_s,
              flagged: params.flagged == true,
              sequential: params.sequential == true,
              estimated_minutes: estimated_minutes(params.estimated_minutes),
              tags: params.tags || []
            }
          end

          def estimated_minutes(value)
            return "" if Utils::Blank.blank?(value)

            value.to_s
          end

          def build_date_pre_scripts(params)
            pre_scripts = []
            vars = {}

            %i[due_date defer_date].each do |key|
              value = params.public_send(key)
              next if Utils::Blank.blank?(value)

              var = "#{key.to_s.split("_").first}Date#{SecureRandom.hex(5)}"
              pre_scripts << Infrastructure::AppleScriptDateBuilder.create_date_outside_tell_block(value.to_s, var)
              vars[key] = var
            end

            [pre_scripts.join("\n\n"), vars]
          end

          def document_body(fields:, date_vars:)
            [
              project_creation(fields),
              "",
              property_setters(fields:, date_vars:),
              "",
              "-- Get the project ID",
              "set projectId to id of newProject as string",
              tag_assignments_block(fields[:tags]),
              %(return "{\\"success\\":true,\\"projectId\\":\\"" & projectId & "\\",\\"name\\":\\"#{fields[:name]}\\"}")
            ].compact.join("\n")
          end

          def project_creation(fields)
            if fields[:folder_name].empty?
              <<~APPLESCRIPT.chomp
                -- Create project at the root level
                set newProject to make new project with properties {name:"#{fields[:name]}"}
              APPLESCRIPT
            else
              escaped = Infrastructure::AppleScript.escape(fields[:folder_name])
              error_json = %({\\"success\\":false,\\"error\\":\\"Folder not found: #{escaped}\\"})
              folder_lookup = Infrastructure::AppleScript.generate_folder_lookup_script(
                raw_folder_path: fields[:folder_name], var_name: "theFolder", error_return_json: error_json
              )
              <<~APPLESCRIPT.chomp
                -- Find the folder (supports nested paths like "Work/Engineering")
                #{folder_lookup}
                set newProject to make new project with properties {name:"#{fields[:name]}"} at end of projects of theFolder
              APPLESCRIPT
            end
          end

          def property_setters(fields:, date_vars:)
            lines = ["-- Set project properties"]
            lines << %(set note of newProject to "#{fields[:note]}") unless fields[:note].empty?

            %i[due_date defer_date].each do |key|
              lines.concat(date_setter_lines(key, date_vars[key])) if date_vars[key]
            end

            lines << "set flagged of newProject to true" if fields[:flagged]

            minutes = fields[:estimated_minutes]
            lines << "set estimated minutes of newProject to #{minutes}" unless minutes.empty?
            lines << "set sequential of newProject to #{fields[:sequential]}"
            lines.join("\n")
          end

          def date_setter_lines(key, var)
            label = key.to_s.split("_").first
            ["-- Set #{label} date", "set #{label} date of newProject to #{var}"]
          end

          def tag_assignments_block(tags)
            return nil if tags.empty?

            blocks = tags.map do |tag|
              Infrastructure::AppleScript.tag_assignment(
                item_var: "newProject",
                tag_name: Infrastructure::AppleScript.escape(tag.to_s)
              )
            end

            "\n-- Add tags if provided\n#{blocks.join("\n")}"
          end
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
