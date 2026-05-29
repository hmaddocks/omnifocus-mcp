# frozen_string_literal: true

module OmnifocusMcp
  module Tools
    module Presenters
      module ListPerspectives
        class << self
          def format(perspectives)
            return "No perspectives found." if perspectives.empty?

            built_in = perspectives.select { |perspective| perspective["type"] == "builtin" }
            custom = perspectives.select { |perspective| perspective["type"] == "custom" }

            output = "## Available Perspectives (#{perspectives.length})\n\n"
            append_group(output:, title: "Built-in Perspectives", perspectives: built_in)
            output << "\n" if built_in.any? && custom.any?
            append_group(output:, title: "Custom Perspectives", perspectives: custom)
            output
          end

          private

          def append_group(output:, title:, perspectives:)
            return if perspectives.empty?

            output << "### #{title}\n"
            perspectives.each { |perspective| output << "• #{perspective["name"]}\n" }
          end
        end
      end
    end
  end
end
