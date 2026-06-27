# frozen_string_literal: true

require_relative "../../utils/blank"
require_relative "../../utils/iso_date"

module OmnifocusMcp
  module Tools
    module Presenters
      # Pure-string formatters for `query_omnifocus` results.
      #
      # Exposes `format_tasks`, `format_projects`, `format_folders`,
      # `format_query_results`, `format_filters`. Used by
      # {Definitions::QueryOmnifocusTool} to build the user-facing text reply.
      module QueryResults
        class << self
          def format_query_results(items:, entity:, filters: nil)
            return "No #{entity} found matching the specified criteria." if items.nil? || items.empty?

            output = "## Query Results: #{items.length} #{entity}\n\n"

            output << "Filters applied: #{format_filters(filters)}\n\n" if filters && !filters.empty?

            output << case entity.to_s
                      when "tasks"    then format_tasks(items)
                      when "projects" then format_projects(items)
                      when "folders"  then format_folders(items)
                      else "Unsupported entity: #{entity}"
                      end

            output
          end

          def format_filters(filters)
            f = stringify_keys(filters)
            parts = []

            parts << %(project ID: "#{f["projectId"]}") if f["projectId"]
            parts << %(project: "#{f["projectName"]}")  if f["projectName"]
            parts << %(task: "#{f["taskName"]}")        if f["taskName"]
            parts << %(folder ID: "#{f["folderId"]}")   if f["folderId"]
            parts << "tags: [#{Array(f["tags"]).join(", ")}]"     if f["tags"]
            parts << "status: [#{Array(f["status"]).join(", ")}]" if f["status"]
            parts << "flagged: #{f["flagged"]}" unless f["flagged"].nil?

            parts << format_within(label: "due", value: f["dueWithin"]) if f["dueWithin"]
            parts << format_deferred(f["deferredUntil"]) if f["deferredUntil"]
            parts << format_within(label: "planned", value: f["plannedWithin"]) if f["plannedWithin"]

            parts << "has note: #{f["hasNote"]}" unless f["hasNote"].nil?
            parts << "inbox: #{f["inbox"]}"      unless f["inbox"].nil?

            parts << format_on(label: "due", value: f["dueOn"]) if f["dueOn"]
            parts << format_on(label: "defer", value: f["deferOn"]) if f["deferOn"]
            parts << format_on(label: "planned", value: f["plannedOn"]) if f["plannedOn"]

            parts << "added within #{f["addedWithin"]} days" if f["addedWithin"]
            parts << "added on day #{f["addedOn"]}" if f["addedOn"]
            parts << "repeating: #{f["isRepeating"]}" unless f["isRepeating"].nil?
            parts << "completed within #{f["completedWithin"]} days" if f["completedWithin"]
            parts << "completed on day #{f["completedOn"]}" if f["completedOn"]

            parts.join(", ")
          end

          def format_tasks(tasks)
            tasks.map { format_task(it) }
                 .join("\n")
          end

          def format_projects(projects)
            projects.map { format_project(it) }
                    .join("\n")
          end

          def format_folders(folders)
            folders.map { format_folder(it) }
                   .join("\n")
          end

          def format_task(task)
            t = stringify_keys(task)
            parts = []

            flag = t["flagged"] ? "🚩 " : ""
            parts << "• #{flag}#{t["name"] || "Unnamed"}"

            parts << "[#{t["id"]}]" if t["id"]
            parts << "(#{t["projectName"]})" if t["projectName"]

            append_date(parts, label: "due", value: t["dueDate"])
            append_date(parts, label: "defer", value: t["deferDate"])
            append_date(parts, label: "planned", value: t["plannedDate"])

            if t["estimatedMinutes"]
              minutes = t["estimatedMinutes"].to_i
              formatted = minutes >= 60 ? "#{minutes / 60}h" : "#{minutes}m"
              parts << "(#{formatted})"
            end

            parts << "<#{Array(t["tagNames"]).join(",")}>" if t["tagNames"] && !t["tagNames"].empty?
            parts << "##{t["taskStatus"].downcase}"        if t["taskStatus"]

            unless t["isRepeating"].nil?
              parts << (t["isRepeating"] ? "[repeating]" : "[not repeating]")
            end

            parts << "[rule: #{t["repetitionRule"]}]" if t["repetitionRule"]
            parts << "[parent: #{t["parentId"]}]"     if t["parentId"]

            if t["hasChildren"] && t["childIds"] && !t["childIds"].empty?
              parts << "[children: #{t["childIds"].join(", ")}]"
            end

            append_date(parts, label: "created", value: t["creationDate"])
            append_date(parts, label: "modified", value: t["modificationDate"])
            append_date(parts, label: "completed", value: t["completionDate"])

            result = parts.join(" ")
            result += "\n  Note: #{t["note"]}" unless Utils::Blank.blank?(t["note"])
            result
          end

          def format_project(project)
            p = stringify_keys(project)

            status     = p["status"] && p["status"] != "Active" ? " [#{p["status"]}]" : ""
            folder     = p["folderName"]                        ? " 📁 #{p["folderName"]}" : ""
            task_count = p["taskCount"].nil?                    ? "" : " (#{p["taskCount"]} tasks)"
            flagged    = p["flagged"] ? "🚩 " : ""
            due        = format_due_segment(p["dueDate"])

            result = "P: #{flagged}#{p["name"]}#{status}#{due}#{folder}#{task_count}"
            result += "\n  Note: #{p["note"]}" unless Utils::Blank.blank?(p["note"])
            result
          end

          def format_folder(folder)
            f = stringify_keys(folder)

            project_count = f["projectCount"].nil? ? "" : " (#{f["projectCount"]} projects)"
            path          = f["path"]              ? " 📍 #{f["path"]}" : ""

            "F: #{f["name"]}#{project_count}#{path}"
          end

          private

          def stringify_keys(hash)
            return {} if hash.nil?

            hash.each_with_object({}) { |(k, v), acc| acc[k.to_s] = v }
          end

          def format_within(label:, value:)
            value.is_a?(String) ? "#{label} within #{value}" : "#{label} within #{value} days"
          end

          def format_deferred(value)
            if value.is_a?(String)
              "deferred within #{value}"
            else
              "deferred becoming available within #{value} days"
            end
          end

          def format_on(label:, value:)
            value.is_a?(String) ? "#{label} on #{value}" : "#{label} on day +#{value}"
          end

          def format_due_segment(date_str)
            formatted = Utils::IsoDate.to_date_only(date_str)
            formatted ? " [due: #{formatted}]" : ""
          end

          def append_date(parts, label:, value:)
            formatted = Utils::IsoDate.to_date_only(value)
            parts << "[#{label}: #{formatted}]" if formatted
          end
        end
      end
    end
  end
end
