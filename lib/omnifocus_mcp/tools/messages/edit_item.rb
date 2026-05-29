# frozen_string_literal: true

module OmnifocusMcp
  module Tools
    module Messages
      module EditItem
        class << self
          def missing_identifier = "Either id or name must be provided to edit an item."

          def success(args, edited)
            label = args[:itemType] == "task" ? "Task" : "Project"
            changed = edited.changed_properties ? " (#{edited.changed_properties})" : ""
            %(✅ #{label} "#{edited.name}" updated successfully#{changed}.)
          end

          def failure(args, error)
            base = "Failed to update #{args[:itemType]}"
            return base unless error

            if error.include?("Item not found")
              not_found_message(args)
            else
              "#{base}: #{error}"
            end
          end

          private

          def not_found_message(args)
            msg = "#{args[:itemType].capitalize} not found"
            msg += %( with ID "#{args[:id]}") if args[:id]
            msg += %(#{args[:id] ? " or" : " with"} name "#{args[:name]}") if args[:name]
            "#{msg}."
          end
        end
      end
    end
  end
end
