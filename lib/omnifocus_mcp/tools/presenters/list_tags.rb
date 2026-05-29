# frozen_string_literal: true

module OmnifocusMcp
  module Tools
    module Presenters
      module ListTags
        class << self
          def format(tags)
            return "No tags found." if tags.empty?

            nested_tags, top_level_tags = tags.partition { |tag| tag["parentTagID"] }
            children_by_parent = nested_tags.group_by { |tag| tag["parentTagID"] }

            output = "## Tags (#{tags.length})\n\n"
            append_top_level_tags(output:, top_level_tags:, children_by_parent:)
            append_orphaned_children(output:, top_level_tags:, children_by_parent:)
            output
          end

          private

          def append_top_level_tags(output:, top_level_tags:, children_by_parent:)
            top_level_tags.each do |tag|
              output << format_tag(tag, "")
              (children_by_parent[tag["id"]] || []).each do |child|
                output << format_tag(child, "  ")
              end
            end
          end

          def append_orphaned_children(output:, top_level_tags:, children_by_parent:)
            rendered_parents = top_level_tags.to_set { |tag| tag["id"] }
            children_by_parent.each do |parent_id, children|
              next if rendered_parents.include?(parent_id)

              children.each { |child| output << format_tag(child, "") }
            end
          end

          def format_tag(tag, indent)
            status = tag["active"] ? "" : " (inactive)"
            tasks = (tag["taskCount"] || 0).positive? ? " [#{tag["taskCount"]} tasks]" : ""
            "#{indent}- **#{tag["name"]}**#{status}#{tasks} (id: #{tag["id"]})\n"
          end
        end
      end
    end
  end
end
