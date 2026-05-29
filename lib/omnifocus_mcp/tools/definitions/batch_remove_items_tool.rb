# frozen_string_literal: true

require "fast_mcp"

require_relative "mcp_envelope"
require_relative "operation_factory"
require_relative "../messages/batch_remove_items"
require_relative "../operations/batch_remove_items"
require_relative "../params"
require_relative "../presenters/batch_report"
require_relative "../../utils/blank"

module OmnifocusMcp
  module Tools
    module Definitions
      # `FastMcp::Tool` for `batch_remove_items`.
      class BatchRemoveItemsTool < FastMcp::Tool
        tool_name "batch_remove_items"
        description "Remove multiple tasks or projects from OmniFocus in a single operation"

        arguments do
          required(:items).array(:hash) do
            optional(:id).filled(:string).description("The ID of the task or project to remove")
            optional(:name).filled(:string).description(
              "The name of the task or project to remove (as fallback if ID not provided)"
            )
            required(:itemType).filled(included_in?: %w[task project])
                               .description("Type of item to remove ('task' or 'project')")
          end.description("Array of items (tasks or projects) to remove")
        end

        extend OperationFactory

        default_operation_factory { Operations::BatchRemoveItems.method(:call) }

        def call(**args)
          items = Array(args[:items]).map { |item| Params::BatchRemoveItemParams.from_mcp(item) }
          if any_missing_identifier?(items)
            return McpEnvelope::ToolReply.failure(Messages::BatchRemoveItems.missing_identifier).to_envelope
          end

          McpEnvelope.safely("processing batch removal") do
            operation.call(items).fold(
              on_ok: ->(results) { success_reply(results, items) },
              on_error: ->(err) { McpEnvelope::ToolReply.failure(Presenters::BatchReport.format_failure(err)) }
            )
          end
        end

        private

        def any_missing_identifier?(items) = items.any? { |i| Utils::Blank.blank?(i.id, i.name) }

        def success_reply(results, items)
          text = Presenters::BatchReport.format_success(
            past_tense: "removed", failure_verb: "remove", results:, items:
          ) { |item_result, item| Presenters::BatchReport.remove_detail(item_result, item) }

          if Presenters::BatchReport.all_failed?(results)
            McpEnvelope::ToolReply.failure(text)
          else
            McpEnvelope::ToolReply.success(text)
          end
        end
      end
    end
  end
end
