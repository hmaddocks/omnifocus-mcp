# frozen_string_literal: true

require_relative "../../result"
require_relative "../../infrastructure/js_embed"
require_relative "../../infrastructure/script_runner"
require_relative "../query_statuses"
require_relative "../params"

module OmnifocusMcp
  module Tools
    module Generators
      # Read-side primitive: build and execute a JXA/OmniJS script that walks
      # the OmniFocus database and returns matching tasks/projects/folders.
      #
      # camelCase MCP arguments are translated to idiomatic snake_case at the
      # tool boundary (see {Tools::Params::QueryOmnifocusParams.from_mcp});
      # this primitive only ever sees {Tools::Params::QueryOmnifocusParams}.
      #
      # Returns an {OmnifocusMcp::Result} whose +ok+ payload is a {Match} with
      # +items+ (Array, +nil+ when called with +summary: true+) and +count+
      # (Integer, may be +nil+ when the script omits it).
      class QueryOmnifocus
        Match = Data.define(:items, :count)

        # Maps API/tool sort field names to OmniFocus JS property names on raw items.
        SORT_FIELD_ALIASES = {
          "name" => "name",
          "dueDate" => "dueDate",
          "deferDate" => "deferDate",
          "plannedDate" => "plannedDate",
          "estimatedMinutes" => "estimatedMinutes",
          "taskStatus" => "taskStatus",
          "status" => "status",
          "flagged" => "flagged",
          "modified" => "modified",
          "modificationDate" => "modified",
          "added" => "added",
          "creationDate" => "added"
        }.freeze
        private_constant :SORT_FIELD_ALIASES

        class << self
          def escape_jxa(str) = Infrastructure::JsEmbed.double_quoted_string(str)

          # Run the generated query against OmniFocus and return a Result.
          def call(params)
            require_relative "../operations/query_omnifocus"

            Operations::QueryOmnifocus.call(params)
          end

          # The OmniJS script emits one of:
          #   { items:, count:, error: null }   — normal listing
          #   { count:, error: null }           — summary mode (no items field)
          #   { error: "...", items: [], count: 0 } — JS try/catch path
          # so the +error+ branch must be checked first; the JS payload always
          # carries +items+/+count+ alongside +error+ when it fails.
          #
          # JSON.parse hands us String keys; pattern matching wants Symbols. A
          # non-Hash response (e.g. raw stdout from a parse failure) becomes
          # +nil+ here so the +in nil+ arm can surface it as an error.
          def classify_response(response:, summary:)
            shape = response.is_a?(Hash) ? response.transform_keys(&:to_sym) : nil

            case shape
            in { error: String => msg }
              OmnifocusMcp::Result.error(msg)
            in { items: Array => items, count: Integer => count }
              OmnifocusMcp::Result.ok(build_match(items:, count:, summary: summary))
            in { count: Integer => count }
              OmnifocusMcp::Result.ok(Match.new(items: nil, count: count))
            in Hash
              OmnifocusMcp::Result.ok(Match.new(items: nil, count: nil))
            in nil
              OmnifocusMcp::Result.error("Unexpected response from queryOmnifocus: #{response.inspect}")
            end
          end

          # Build a {Match} from a normal items+count payload. In +summary+ mode
          # the items array is dropped; otherwise the array is passed through
          # verbatim.
          def build_match(items:, count:, summary:) = Match.new(items: summary ? nil : items, count: count)

          # Build the full JXA query script for the given params.
          def generate_query_script(params)
            params = Params::McpBoundary.coerce(Params::QueryOmnifocusParams, params)

            entity = params.entity.to_s

            filters = params.filters || {}
            filter_conditions = generate_filter_conditions(entity:, filters:)

            field_mapping = generate_field_mapping(entity:, fields: params.fields)

            sort_property = resolve_sort_field(params.sort_by)
            sort_logic = sort_property ? generate_sort_logic(sort_property, sort_order: params.sort_order) : ""

            limit = params.limit
            limit_logic = limit.is_a?(Integer) && limit.positive? ? "filtered = filtered.slice(0, #{limit});" : ""

            build_query_script(
              entity: entity,
              include_completed: params.include_completed == true,
              summary: params.summary == true,
              filter_conditions: filter_conditions,
              field_mapping: field_mapping,
              sort_logic: sort_logic,
              limit_logic: limit_logic
            )
          end

          # Build the per-item filter expressions for the JXA `filter` body.
          def generate_filter_conditions(entity:, filters:)
            f = filters || {}
            conditions = []

            if entity == "tasks"
              apply_task_name_filters(filters: f, conditions:)
              apply_task_id_filters(filters: f, conditions:)
              apply_tag_status_filters(filters: f, conditions:, entity: "tasks")
              apply_task_date_filters(filters: f, conditions:)
              apply_task_misc_filters(filters: f, conditions:)
            elsif entity == "projects"
              apply_project_folder_filter(filters: f, conditions:)
              apply_tag_status_filters(filters: f, conditions:, entity: "projects")
              apply_project_date_filters(filters: f, conditions:)
            end

            conditions.join("\n")
          end

          # Generate a JXA `filtered.sort(...)` block keyed by a whitelisted property name.
          def generate_sort_logic(sort_property, sort_order: nil)
            order = sort_order.to_s == "desc" ? -1 : 1

            <<~JS
              filtered.sort((a, b) => {
                let aVal = a.#{sort_property};
                let bVal = b.#{sort_property};

                // Handle null/undefined values
                if (aVal == null && bVal == null) return 0;
                if (aVal == null) return 1;
                if (bVal == null) return -1;

                // Compare based on type
                if (typeof aVal === 'string') {
                  return aVal.localeCompare(bVal) * #{order};
                } else if (aVal instanceof Date) {
                  return (aVal.getTime() - bVal.getTime()) * #{order};
                } else {
                  return (aVal - bVal) * #{order};
                }
              });
            JS
          end

          # Build the per-item field-projection block. With no `fields` array
          # (nil or empty), returns the default field set for the entity.
          # Otherwise builds explicit mappings for each requested field.
          def generate_field_mapping(entity:, fields: nil)
            if fields.nil? || fields.empty?
              return default_task_mapping if entity == "tasks"
              return default_project_mapping if entity == "projects"
              return default_folder_mapping if entity == "folders"
            end

            mappings = fields.map { |field| field_mapping_for(field) }.join(",\n          ")

            <<~JS
              return {
                #{mappings}
              };
            JS
          end

          def apply_task_name_filters(filters:, conditions:)
            if filters[:project_name]
              safe_name = escape_jxa(filters[:project_name].to_s.downcase)
              conditions << <<~JS
                if (item.containingProject) {
                  const projectName = item.containingProject.name.toLowerCase();
                  if (!projectName.includes("#{safe_name}")) return false;
                } else if ("#{safe_name}" !== "inbox") {
                  return false;
                }
              JS
            end

            return unless filters[:task_name]

            safe_name = escape_jxa(filters[:task_name].to_s.downcase)
            conditions << <<~JS
              const taskName = (item.name || "").toLowerCase();
              if (!taskName.includes("#{safe_name}")) return false;
            JS
          end

          # rubocop:disable Metrics/MethodLength
          def apply_task_id_filters(filters:, conditions:)
            if filters[:project_id]
              safe_id = escape_jxa(filters[:project_id])
              conditions << <<~JS
                if (!item.containingProject ||
                    item.containingProject.id.primaryKey !== "#{safe_id}") {
                  return false;
                }
              JS
            end

            return unless filters[:folder_id]

            conditions << <<~JS
              {
                const targetFolderId = "#{escape_jxa(filters[:folder_id])}";
                let matchesFolder = false;
                if (item.containingProject && item.containingProject.parentFolder) {
                  let folder = item.containingProject.parentFolder;
                  while (folder) {
                    if (folder.id.primaryKey === targetFolderId) {
                      matchesFolder = true;
                      break;
                    }
                    folder = folder.parentFolder;
                  }
                }
                if (!matchesFolder) return false;
              }
            JS
          end
          # rubocop:enable Metrics/MethodLength

          def apply_tag_status_filters(filters:, conditions:, entity:)
            if entity == "tasks" && filters[:tags] && !filters[:tags].empty?
              conditions << tag_filter_condition(filters[:tags])
            end

            return unless filters[:status] && !filters[:status].empty?

            status_map = if entity == "tasks"
                           "taskStatusMap[item.taskStatus]"
                         else
                           "projectStatusMap[item.status]"
                         end
            status_condition = filters[:status].map { |s| %(#{status_map} === "#{escape_jxa(s)}") }.join(" || ")
            conditions << "if (!(#{status_condition})) return false;"
          end

          def tag_filter_condition(tags)
            tag_condition = tags.map do |tag|
              %(item.tags.some(t => t.name === "#{escape_jxa(tag)}"))
            end.join(" || ")
            "if (!(#{tag_condition})) return false;"
          end

          def apply_task_date_filters(filters:, conditions:)
            conditions << "if (item.flagged !== #{filters[:flagged]}) return false;" unless filters[:flagged].nil?

            push_within(conditions:, field: "dueDate", value: filters[:due_within])
            push_within(conditions:, field: "plannedDate", value: filters[:planned_within])
            push_within(conditions:, field: "deferDate", value: filters[:deferred_until])

            push_same_day(conditions:, field: "dueDate", value: filters[:due_on])
            push_same_day(conditions:, field: "deferDate", value: filters[:defer_on])
            push_same_day(conditions:, field: "plannedDate", value: filters[:planned_on])
            push_same_day(conditions:, field: "added", value: filters[:added_on])
            push_same_day(conditions:, field: "completionDate", value: filters[:completed_on])

            push_within_past(conditions:, field: "added", value: filters[:added_within])
            push_within_past(conditions:, field: "completionDate", value: filters[:completed_within])
          end

          def apply_task_misc_filters(filters:, conditions:)
            unless filters[:is_repeating].nil?
              conditions << if filters[:is_repeating]
                              "if (item.repetitionRule === null) return false;"
                            else
                              "if (item.repetitionRule !== null) return false;"
                            end
            end

            unless filters[:has_note].nil?
              conditions << <<~JS
                const hasNote = item.note && item.note.trim().length > 0;
                if (hasNote !== #{filters[:has_note]}) return false;
              JS
            end

            return if filters[:inbox].nil?

            conditions << if filters[:inbox]
                            "if (!item.inInbox) return false;"
                          else
                            "if (item.inInbox) return false;"
                          end
          end

          def apply_project_folder_filter(filters:, conditions:)
            return unless filters[:folder_id]

            conditions << <<~JS
              {
                const targetFolderId = "#{escape_jxa(filters[:folder_id])}";
                let matchesFolder = false;
                if (item.parentFolder) {
                  let folder = item.parentFolder;
                  while (folder) {
                    if (folder.id.primaryKey === targetFolderId) {
                      matchesFolder = true;
                      break;
                    }
                    folder = folder.parentFolder;
                  }
                }
                if (!matchesFolder) return false;
              }
            JS
          end

          def apply_project_date_filters(filters:, conditions:)
            push_within_past(conditions:, field: "added", value: filters[:added_within])
            push_same_day(conditions:, field: "added", value: filters[:added_on])
            push_within_past(conditions:, field: "completionDate", value: filters[:completed_within])
            push_same_day(conditions:, field: "completionDate", value: filters[:completed_on])
          end

          # Forward-looking date filter: passes if the date exists and is at most
          # `n_days` in the future. Same semantics as the OmniJS date filter helpers.
          def push_within(conditions:, field:, value:)
            return if value.nil?

            conditions << <<~JS
              if (!item.#{field} || !checkDateFilter(item.#{field}, #{value})) {
                return false;
              }
            JS
          end

          # Backward-looking variant: passes if the date is within the last N days.
          def push_within_past(conditions:, field:, value:)
            return if value.nil?

            conditions << <<~JS
              if (!item.#{field} || !checkDateWithinPast(item.#{field}, #{value})) {
                return false;
              }
            JS
          end

          # Exact-day match (offset relative to today).
          def push_same_day(conditions:, field:, value:)
            return if value.nil?

            conditions << "if (!checkSameDay(item.#{field}, #{value})) return false;"
          end

          def default_task_mapping
            <<~JS
              const obj = {
                id: item.id.primaryKey,
                name: item.name || "",
                flagged: item.flagged || false,
                taskStatus: taskStatusMap[item.taskStatus] || "Unknown",
                dueDate: formatDate(item.dueDate),
                deferDate: formatDate(item.deferDate),
                plannedDate: formatDate(item.plannedDate),
                tagNames: item.tags ? item.tags.map(t => t.name) : [],
                projectName: item.containingProject ? item.containingProject.name : (item.inInbox ? "Inbox" : null),
                estimatedMinutes: item.estimatedMinutes || null,
                note: item.note || ""
              };
              return obj;
            JS
          end

          def default_project_mapping
            <<~JS
              const taskArray = item.tasks || [];
              return {
                id: item.id.primaryKey,
                name: item.name || "",
                status: projectStatusMap[item.status] || "Unknown",
                folderName: item.parentFolder ? item.parentFolder.name : null,
                taskCount: taskArray.length,
                flagged: item.flagged || false,
                dueDate: formatDate(item.dueDate),
                deferDate: formatDate(item.deferDate),
                note: item.note || ""
              };
            JS
          end

          def default_folder_mapping
            <<~JS
              const projectArray = item.projects || [];
              return {
                id: item.id.primaryKey,
                name: item.name || "",
                projectCount: projectArray.length,
                path: item.container ? item.container.name + "/" + item.name : item.name
              };
            JS
          end

          FIELD_MAPPINGS = {
            "id" => "id: item.id.primaryKey",
            "taskStatus" => "taskStatus: taskStatusMap[item.taskStatus]",
            "status" => "status: projectStatusMap[item.status]",
            "modificationDate" => "modificationDate: formatDate(item.modified)",
            "modified" => "modificationDate: formatDate(item.modified)",
            "creationDate" => "creationDate: formatDate(item.added)",
            "added" => "creationDate: formatDate(item.added)",
            "completionDate" => "completionDate: item.completionDate ? formatDate(item.completionDate) : null",
            "dueDate" => "dueDate: formatDate(item.dueDate)",
            "deferDate" => "deferDate: formatDate(item.deferDate)",
            "plannedDate" => "plannedDate: formatDate(item.plannedDate)",
            "effectiveDueDate" => "effectiveDueDate: formatDate(item.effectiveDueDate)",
            "effectiveDeferDate" => "effectiveDeferDate: formatDate(item.effectiveDeferDate)",
            "effectivePlannedDate" => "effectivePlannedDate: formatDate(item.effectivePlannedDate)",
            "tagNames" => "tagNames: item.tags ? item.tags.map(t => t.name) : []",
            "tags" => "tags: item.tags ? item.tags.map(t => t.id.primaryKey) : []",
            "projectName" => 'projectName: item.containingProject ? item.containingProject.name : (item.inInbox ? "Inbox" : null)',
            "projectId" => "projectId: item.containingProject ? item.containingProject.id.primaryKey : null",
            "parentId" => "parentId: item.parent ? item.parent.id.primaryKey : null",
            "childIds" => "childIds: item.children ? item.children.map(c => c.id.primaryKey) : []",
            "hasChildren" => "hasChildren: item.children ? item.children.length > 0 : false",
            "folderName" => "folderName: item.parentFolder ? item.parentFolder.name : null",
            "folderID" => "folderID: item.parentFolder ? item.parentFolder.id.primaryKey : null",
            "taskCount" => "taskCount: item.tasks ? item.tasks.length : 0",
            "tasks" => "tasks: item.tasks ? item.tasks.map(t => t.id.primaryKey) : []",
            "projectCount" => "projectCount: item.projects ? item.projects.length : 0",
            "projects" => "projects: item.projects ? item.projects.map(p => p.id.primaryKey) : []",
            "subfolders" => "subfolders: item.folders ? item.folders.map(f => f.id.primaryKey) : []",
            "path" => 'path: item.container ? item.container.name + "/" + item.name : item.name',
            "isRepeating" => "isRepeating: item.repetitionRule !== null",
            "repetitionRule" => "repetitionRule: item.repetitionRule ? item.repetitionRule.toString() : null",
            "estimatedMinutes" => "estimatedMinutes: item.estimatedMinutes || null",
            "note" => 'note: item.note || ""'
          }.freeze

          def field_mapping_for(field)
            field_str = field.to_s
            FIELD_MAPPINGS[field_str] || "#{field_str}: item.#{field_str} !== undefined ? item.#{field_str} : null"
          end

          def resolve_sort_field(sort_by)
            return nil if sort_by.nil?

            SORT_FIELD_ALIASES[sort_by.to_s]
          end

          def js_task_status_map_entries
            QueryStatuses::TASK.map do |status|
              %([Task.Status.#{status}]: "#{status}")
            end.join(",\n                  ")
          end

          def js_project_status_map_entries
            QueryStatuses::PROJECT.map do |status|
              %([Project.Status.#{status}]: "#{status}")
            end.join(",\n                  ")
          end

          def build_query_script(entity:, include_completed:, summary:, filter_conditions:, field_mapping:, sort_logic:,
                                 limit_logic:)
            <<~JS
              (() => {
                try {

                  function formatDate(date) {
                    if (!date) return null;
                    return date.toISOString();
                  }

                  function checkDateFilter(itemDate, daysFromNow) {
                    if (!itemDate) return false;
                    const futureDate = new Date();
                    futureDate.setDate(futureDate.getDate() + daysFromNow);
                    return itemDate <= futureDate;
                  }

                  function checkDateWithinPast(itemDate, daysAgo) {
                    if (!itemDate) return false;
                    const pastDate = new Date();
                    pastDate.setDate(pastDate.getDate() - daysAgo);
                    pastDate.setHours(0, 0, 0, 0);
                    return itemDate >= pastDate;
                  }

                  function checkSameDay(itemDate, daysFromNow) {
                    if (!itemDate) return false;
                    const target = new Date();
                    target.setDate(target.getDate() + daysFromNow);
                    return itemDate.getFullYear() === target.getFullYear() &&
                           itemDate.getMonth() === target.getMonth() &&
                           itemDate.getDate() === target.getDate();
                  }

                  const taskStatusMap = {
                    #{js_task_status_map_entries}
                  };

                  const projectStatusMap = {
                    #{js_project_status_map_entries}
                  };

                  let items = [];
                  const entityType = "#{entity}";

                  if (entityType === "tasks") {
                    items = flattenedTasks;
                  } else if (entityType === "projects") {
                    items = flattenedProjects;
                  } else if (entityType === "folders") {
                    items = flattenedFolders;
                  }

                  let filtered = items.filter(item => {
                    if (!#{include_completed}) {
                      if (entityType === "tasks") {
                        if (item.taskStatus === Task.Status.Completed ||
                            item.taskStatus === Task.Status.Dropped) {
                          return false;
                        }
                      } else if (entityType === "projects") {
                        if (item.status === Project.Status.Done ||
                            item.status === Project.Status.Dropped) {
                          return false;
                        }
                      }
                    }

                    #{filter_conditions}

                    return true;
                  });

                  #{sort_logic}

                  #{limit_logic}

                  if (#{summary}) {
                    return JSON.stringify({
                      count: filtered.length,
                      error: null
                    });
                  }

                  const results = filtered.map(item => {
                    #{field_mapping}
                  });

                  return JSON.stringify({
                    items: results,
                    count: results.length,
                    error: null
                  });

                } catch (error) {
                  return JSON.stringify({
                    error: "Script execution error: " + error.toString(),
                    items: [],
                    count: 0
                  });
                }
              })();
            JS
          end
        end
      end
    end
  end
end
