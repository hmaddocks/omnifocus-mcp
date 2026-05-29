# frozen_string_literal: true

require "fast_mcp"

require_relative "mcp_envelope"
require_relative "operation_factory"
require_relative "../operations/query_omnifocus"
require_relative "../params"
require_relative "../presenters/query_reply"
require_relative "../query_statuses"
require_relative "../../utils/date_filter"

module OmnifocusMcp
  module Tools
    module Definitions
      # `FastMcp::Tool` for `query_omnifocus`.
      class QueryOmnifocusTool < FastMcp::Tool
        tool_name "query_omnifocus"
        description "Efficiently query OmniFocus database with powerful filters. " \
                    "Get specific tasks, projects, or folders without loading the entire database. " \
                    "Supports filtering by project, tags, status, due dates, and more."

        DATE_FILTER_FIELDS = %i[due_within deferred_until planned_within due_on defer_on planned_on].freeze

        # rubocop:disable Metrics/BlockLength
        arguments do
          required(:entity).filled(included_in?: %w[tasks projects folders]).description(
            "Type of entity to query. Choose 'tasks' for individual tasks, 'projects' for projects, " \
            "or 'folders' for folder organization"
          )

          optional(:filters).hash do
            optional(:projectId)
              .filled(:string)
              .description("Filter tasks by exact project ID (use when you know the specific project ID)")
            optional(:projectName).filled(:string).description(
              "Filter tasks by project name. CASE-INSENSITIVE PARTIAL MATCHING - 'review' matches " \
              "'Weekly Review', 'Review Documents', etc. Special value: 'inbox' returns inbox tasks"
            )
            optional(:taskName).filled(:string).description(
              "Filter tasks by task name. CASE-INSENSITIVE PARTIAL MATCHING - 'email' matches " \
              "'Send email to IT', 'Confirm email' etc. Useful for fuzzy searching specific tasks across all projects"
            )
            optional(:folderId).filled(:string).description(
              "Filter by folder ID. For tasks, returns tasks whose containing project is in this folder " \
              "(or a subfolder). For projects, returns projects in this folder (or a subfolder)"
            )
            optional(:tags).array(:string).description(
              "Filter by tag names. EXACT MATCH, CASE-SENSITIVE. OR logic - items must have at least " \
              "ONE of the specified tags. Example: ['Work'] and ['work'] are different"
            )
            optional(:status).array(:string).description(
              "Filter by status (OR logic - matches any). TASKS: #{QueryStatuses.task_list_for_schema} " \
              "(next action, ready to work, waiting, due <24h, past due, completed, dropped). " \
              "PROJECTS: #{QueryStatuses.project_list_for_schema}"
            )
            optional(:flagged).filled(:bool).description(
              "Filter by flagged status. true = only flagged items, false = only unflagged items"
            )
            optional(:dueWithin).maybe { int? | str? }.description(
              "Returns items due from TODAY through N days in future. Accepts: number (days), 'today', " \
              "'tomorrow', 'this week', 'next week', or ISO date 'YYYY-MM-DD'"
            )
            optional(:deferredUntil).maybe { int? | str? }.description(
              "Returns items CURRENTLY DEFERRED that will become available within N days. Accepts: number " \
              "(days), 'today', 'tomorrow', 'this week', 'next week', or ISO date 'YYYY-MM-DD'"
            )
            optional(:plannedWithin).maybe { int? | str? }.description(
              "Returns tasks planned from TODAY through N days in future. Accepts: number (days), 'today', " \
              "'tomorrow', 'this week', 'next week', or ISO date 'YYYY-MM-DD'"
            )
            optional(:hasNote).filled(:bool).description(
              "Filter by note presence. true = items with non-empty notes (whitespace ignored), " \
              "false = items with no notes or only whitespace"
            )
            optional(:inbox).filled(:bool).description(
              "Filter tasks by inbox status. true = only inbox tasks (no project), false = only tasks in a project"
            )
            optional(:dueOn).maybe { int? | str? }.description(
              "Returns items due on exactly this day. Accepts: number (0 = today, 1 = tomorrow), 'today', " \
              "'tomorrow', 'this week', 'next week', or ISO date 'YYYY-MM-DD'"
            )
            optional(:deferOn).maybe { int? | str? }.description(
              "Returns items with defer date on exactly this day. Accepts: number (0 = today, 1 = tomorrow), " \
              "'today', 'tomorrow', 'this week', 'next week', or ISO date 'YYYY-MM-DD'"
            )
            optional(:plannedOn).maybe { int? | str? }.description(
              "Returns tasks with planned date on exactly this day. Accepts: number (0 = today, 1 = tomorrow), " \
              "'today', 'tomorrow', 'this week', 'next week', or ISO date 'YYYY-MM-DD'"
            )
            optional(:addedWithin).filled(:integer).description(
              "Returns items added (created) within the last N days. Example: 7 = items added in the last week"
            )
            optional(:addedOn).filled(:integer).description(
              "Returns items added (created) on exactly this day. 0 = today, 1 = tomorrow, -1 = yesterday. " \
              "Negative values look backward"
            )
            optional(:isRepeating)
              .filled(:bool)
              .description("Filter by repeating status. true = only repeating tasks, false = only non-repeating tasks")
            optional(:completedWithin).filled(:integer).description(
              "Returns items completed or dropped within the last N days (uses completionDate which OmniFocus " \
              "sets for both). Example: 7 = items completed in the last week. Combine with status: ['Dropped'] " \
              "to find only dropped items. Note: use with includeCompleted: true"
            )
            optional(:completedOn).filled(:integer).description(
              "Returns items completed or dropped on exactly this day (uses completionDate which OmniFocus sets " \
              "for both). 0 = today, -1 = yesterday. Negative values look backward. Combine with status: " \
              "['Dropped'] to find only dropped items. Note: use with includeCompleted: true"
            )
          end.description(
            "Optional filters to narrow results. ALL filters combine with AND logic (must match all). " \
            "Within array filters (tags, status) OR logic applies"
          )

          optional(:fields).array(:string).description(
            "Specific fields to return (reduces response size). TASK FIELDS: id, name, note, flagged, " \
            "taskStatus, dueDate, deferDate, plannedDate, effectiveDueDate, effectiveDeferDate, " \
            "effectivePlannedDate, completionDate, estimatedMinutes, tagNames, tags, projectName, projectId, " \
            "parentId, childIds, hasChildren, sequential, completedByChildren, inInbox, isRepeating, " \
            "repetitionRule, modificationDate (or modified), creationDate (or added). PROJECT FIELDS: id, " \
            "name, status, note, folderName, folderID, sequential, dueDate, deferDate, effectiveDueDate, " \
            "effectiveDeferDate, completedByChildren, containsSingletonActions, taskCount, tasks, " \
            "modificationDate, creationDate. FOLDER FIELDS: id, name, path, parentFolderID, status, " \
            "projectCount, projects, subfolders. NOTE: Date fields use 'added' and 'modified' in OmniFocus API"
          )
          optional(:limit)
            .filled(:integer)
            .description("Maximum number of items to return. Useful for large result sets. Default: no limit")
          optional(:sortBy).filled(:string).description(
            "Field to sort by. OPTIONS: name (alphabetical), dueDate (earliest first, null last), " \
            "deferDate (earliest first, null last), modificationDate (most recent first), creationDate " \
            "(oldest first), estimatedMinutes (shortest first), taskStatus (groups by status)"
          )
          optional(:sortOrder).filled(included_in?: %w[asc desc]).description(
            "Sort order. 'asc' = ascending (A-Z, old-new, small-large), 'desc' = descending (Z-A, new-old, " \
            "large-small). Default: 'asc'"
          )
          optional(:includeCompleted).filled(:bool).description(
            "Include completed and dropped items. Default: false (active items only)"
          )
          optional(:format).filled(included_in?: %w[text json]).description(
            "Output format. 'text' returns the default human-readable report; 'json' returns structured JSON."
          )
          optional(:summary)
            .filled(:bool)
            .description("Return only count of matches, not full details. Efficient for statistics. Default: false")
        end
        # rubocop:enable Metrics/BlockLength

        extend OperationFactory

        default_operation_factory { Operations::QueryOmnifocus.method(:call) }

        def call(**args)
          McpEnvelope.safely("executing query") do
            params = resolve_date_filters(Params::QueryOmnifocusParams.from_mcp(args))

            operation.call(params).fold(
              on_ok: lambda { |match|
                McpEnvelope::ToolReply.success(Presenters::QueryReply.format(args:, params:, match:))
              },
              on_error: ->(err) { McpEnvelope::ToolReply.failure(Presenters::QueryReply.failure(err)) }
            )
          end
        end

        private

        # Resolve named/ISO date filters before querying. Expects a
        # {Params::QueryOmnifocusParams} whose +filters+ hash is already
        # snake_case.
        def resolve_date_filters(params)
          return params unless params.filters

          f = params.filters.dup
          DATE_FILTER_FIELDS.each do |field|
            next if f[field].nil?

            f[field] = Utils::DateFilter.to_days(Utils::DateFilter.parse(f[field]))
          end
          Params::QueryOmnifocusParams.new(**params.to_h, filters: f)
        end
      end
    end
  end
end
