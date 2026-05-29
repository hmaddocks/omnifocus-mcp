# frozen_string_literal: true

module OmnifocusMcp
  module Tools
    module Messages
      module RemoveItem
        class << self
          def missing_identifier = "Either id or name must be provided to remove an item."

          def invalid_item_type(item_type)
            "Invalid item type: #{item_type}. Must be either 'task' or 'project'."
          end

          def success(args, removed)
            label = args[:itemType] == "task" ? "Task" : "Project"
            %(✅ #{label} "#{removed.name}" removed successfully.)
          end

          def failure(args, error)
            base = "Failed to remove #{args[:itemType]}"
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
