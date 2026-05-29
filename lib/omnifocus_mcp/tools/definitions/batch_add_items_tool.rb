# frozen_string_literal: true

require "fast_mcp"

require_relative "mcp_envelope"
require_relative "operation_factory"
require_relative "../operations/batch_add_items"
require_relative "../params"
require_relative "../presenters/batch_report"

module OmnifocusMcp
  module Tools
    module Definitions
      # `FastMcp::Tool` for `batch_add_items`.
      class BatchAddItemsTool < FastMcp::Tool
        tool_name "batch_add_items"
        description "Add multiple tasks or projects to OmniFocus in a single operation"

        # rubocop:disable Metrics/BlockLength
        arguments do
          required(:items).array(:hash) do
            required(:type).filled(included_in?: %w[task project])
                           .description("Type of item to add ('task' or 'project')")
            required(:name).filled(:string).description("The name of the item")
            optional(:note).filled(:string).description("Additional notes for the item")
            optional(:dueDate).filled(:string)
                              .description("The due date in ISO format (YYYY-MM-DD or full ISO date)")
            optional(:deferDate).filled(:string)
                                .description("The defer date in ISO format (YYYY-MM-DD or full ISO date)")
            optional(:plannedDate).filled(:string).description(
              "The planned date in ISO format (YYYY-MM-DD or full ISO date) - tasks only"
            )
            optional(:flagged).filled(:bool).description("Whether the item is flagged or not")
            optional(:estimatedMinutes).filled(:integer)
                                       .description("Estimated time to complete the item, in minutes")
            optional(:tags).array(:string).description("Tags to assign to the item")

            optional(:projectName).filled(:string)
                                  .description("For tasks: The name of the project to add the task to")
            optional(:parentTaskId).filled(:string).description("For tasks: ID of the parent task")
            optional(:parentTaskName).filled(:string).description(
              "For tasks: Name of the parent task (scoped to project when provided)"
            )
            optional(:tempId).filled(:string).description("For tasks: Temporary ID for within-batch references")
            optional(:parentTempId).filled(:string)
                                   .description("For tasks: Reference to parent's tempId within the batch")
            optional(:hierarchyLevel).filled(:integer, gteq?: 0)
                                     .description("Optional ordering hint (0=root, 1=child, ...)")

            optional(:folderName).filled(:string)
                                 .description("For projects: The name of the folder to add the project to")
            optional(:sequential).filled(:bool)
                                 .description("For projects: Whether tasks in the project should be sequential")
          end.description("Array of items (tasks or projects) to add")
          optional(:createSequentially).filled(:bool).description(
            "Process parents before children; when false, best-effort order will still try to resolve parents first"
          )
        end
        # rubocop:enable Metrics/BlockLength

        extend OperationFactory

        default_operation_factory { Operations::BatchAddItems.method(:call) }

        def call(**args)
          McpEnvelope.safely("processing batch operation") do
            items = Array(args[:items]).map { |item| Params::BatchAddItemParams.from_mcp(item) }
            result = operation.call(items)

            result.fold(
              on_ok: ->(per_item) { success_reply(per_item, items) },
              on_error: ->(error) { failure_reply(error) }
            )
          end
        end

        private

        def failure_reply(error)
          OmnifocusMcp.logger.warn("[batch_add_items] failure result: #{error.inspect}")

          McpEnvelope::ToolReply.failure(
            Presenters::BatchReport.format_failure(
              error, results: [], items: []
            ) { |item_result, item| Presenters::BatchReport.add_detail(item_result, item) }
          )
        end

        def success_reply(per_item, items)
          text = Presenters::BatchReport.format_success(
            past_tense: "added", failure_verb: "add", results: per_item, items: items
          ) do |item_result, item|
            Presenters::BatchReport.add_detail(item_result, item)
          end

          if Presenters::BatchReport.all_failed?(per_item)
            McpEnvelope::ToolReply.failure(text)
          else
            McpEnvelope::ToolReply.success(text)
          end
        end
      end
    end
  end
end
