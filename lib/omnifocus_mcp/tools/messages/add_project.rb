# frozen_string_literal: true

require_relative "../definitions/date_formatter"

module OmnifocusMcp
  module Tools
    module Messages
      module AddProject
        class << self
          def success(args)
            location = args[:folderName] ? %(in folder "#{args[:folderName]}") : "at the root level"
            tags = args[:tags] && !args[:tags].empty? ? " with tags: #{args[:tags].join(", ")}" : ""
            due = if args[:dueDate]
                    " due on #{Definitions::DateFormatter.format_date(args[:dueDate], style: :locale)}"
                  else
                    ""
                  end
            sequential = args[:sequential] ? " (sequential)" : " (parallel)"

            %(✅ Project "#{args[:name]}" created successfully #{location}#{due}#{tags}#{sequential}.)
          end

          def failure(error) = "Failed to create project: #{error}"
        end
      end
    end
  end
end
