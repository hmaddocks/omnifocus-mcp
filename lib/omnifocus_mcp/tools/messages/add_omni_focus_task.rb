# frozen_string_literal: true

require_relative "../definitions/date_formatter"

module OmnifocusMcp
  module Tools
    module Messages
      module AddOmniFocusTask
        class << self
          def success(args, result)
            location_text = location_for(args, result.placement)
            tag_text = tag_text_for(args[:tags])
            due_text = if args[:dueDate]
                         " due on #{Definitions::DateFormatter.format_date(args[:dueDate],
                                                                           style: :locale)}"
                       else
                         ""
                       end
            warning = placement_warning(args, result.placement)

            %(✅ Task "#{args[:name]}" created successfully #{location_text}#{due_text}#{tag_text}.#{warning})
          end

          def failure(error) = "Failed to create task: #{error}"

          private

          def location_for(args, placement)
            case placement
            when "parent"  then "under the parent task"
            when "project" then args[:projectName] ? %(in project "#{args[:projectName]}") : "in a project"
            else                "in your inbox"
            end
          end

          def tag_text_for(tags)
            tags && !tags.empty? ? " with tags: #{tags.join(", ")}" : ""
          end

          def placement_warning(args, placement)
            return "" if placement.nil? || placement == "parent"

            parent_requested = args[:parentTaskId] || args[:parentTaskName]
            return "" unless parent_requested

            location = placement == "project" ? "in project" : "in inbox"
            "\n⚠️ Parent not found; task created #{location}."
          end
        end
      end
    end
  end
end
