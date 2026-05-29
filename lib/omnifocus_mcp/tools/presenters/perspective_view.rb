# frozen_string_literal: true

require_relative "../definitions/date_formatter"

module OmnifocusMcp
  module Tools
    module Presenters
      module PerspectiveView
        class << self
          def format(perspective_name, items, limit)
            output = "## #{perspective_name} Perspective (#{items.length} items)\n\n"

            if items.empty?
              output << "No items visible in this perspective."
              return output
            end

            items.each { |item| append_item(output, item) }
            append_limit_warning(output:, items:, limit:)
            output
          end

          private

          def append_item(output, item)
            output << "• #{format_parts(item).join(" ")}\n"
            append_note_preview(output, item["note"]) if item["note"] && !item["note"].to_s.strip.empty?
          end

          def format_parts(item)
            parts = []
            flag = item["flagged"] ? "🚩 " : ""
            checkbox = item["completed"] ? "☑" : "☐"
            parts << "#{checkbox} #{flag}#{item["name"] || "Unnamed"}"

            parts << "(#{item["projectName"]})" if item["projectName"]
            if item["dueDate"]
              parts << "[due: #{Definitions::DateFormatter.format_date(item["dueDate"],
                                                                       style: :compact)}]"
            end
            if item["deferDate"]
              parts << "[defer: #{Definitions::DateFormatter.format_date(item["deferDate"],
                                                                         style: :compact)}]"
            end
            append_estimate(parts, item["estimatedMinutes"])
            parts << "<#{item["tagNames"].join(",")}>" if item["tagNames"] && !item["tagNames"].empty?
            parts << "##{item["taskStatus"].downcase}" if item["taskStatus"] && item["taskStatus"] != "Available"
            parts << "[#{item["id"]}]" if item["id"]
            parts
          end

          def append_estimate(parts, estimated_minutes)
            return unless estimated_minutes

            minutes = estimated_minutes.to_i
            formatted = if minutes >= 60
                          remainder = minutes % 60
                          remainder.positive? ? "#{minutes / 60}h#{remainder}m" : "#{minutes / 60}h"
                        else
                          "#{minutes}m"
                        end
            parts << "(#{formatted})"
          end

          def append_note_preview(output, note)
            first_line = note.strip.split("\n").first.to_s
            preview = first_line.slice(0, 80)
            ellipsis = note.length > 80 || note.include?("\n") ? "..." : ""
            output << "  └─ #{preview}#{ellipsis}\n"
          end

          def append_limit_warning(output:, items:, limit:)
            return unless items.length == limit

            output << "\n⚠️ Results limited to #{limit} items. More may be available in this perspective."
          end
        end
      end
    end
  end
end
