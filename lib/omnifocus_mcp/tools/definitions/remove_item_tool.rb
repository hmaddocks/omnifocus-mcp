# frozen_string_literal: true

require "fast_mcp"

require_relative "mcp_envelope"
require_relative "operation_factory"
require_relative "../messages/remove_item"
require_relative "../operations/remove_item"
require_relative "../params"
require_relative "../../utils/blank"

module OmnifocusMcp
  module Tools
    module Definitions
      # `FastMcp::Tool` for `remove_item`.
      class RemoveItemTool < FastMcp::Tool
        tool_name "remove_item"
        description "Remove a task or project from OmniFocus"

        arguments do
          optional(:id).filled(:string).description("The ID of the task or project to remove")
          optional(:name).filled(:string)
                         .description("The name of the task or project to remove (as fallback if ID not provided)")
          required(:itemType).filled(included_in?: %w[task project])
                             .description("Type of item to remove ('task' or 'project')")
        end

        extend OperationFactory

        default_operation_factory { Operations::RemoveItem.method(:call) }

        def call(**args)
          if missing_identifier?(args)
            return McpEnvelope::ToolReply.failure(Messages::RemoveItem.missing_identifier).to_envelope
          end

          unless %w[task project].include?(args[:itemType])
            return McpEnvelope::ToolReply.failure(Messages::RemoveItem.invalid_item_type(args[:itemType])).to_envelope
          end

          McpEnvelope.safely("removing #{args[:itemType]}") do
            operation.call(Params::RemoveItemParams.from_mcp(args)).fold(
              on_ok: ->(removed) { McpEnvelope::ToolReply.success(Messages::RemoveItem.success(args, removed)) },
              on_error: ->(err) { McpEnvelope::ToolReply.failure(Messages::RemoveItem.failure(args, err)) }
            )
          end
        end

        private

        def missing_identifier?(args) = Utils::Blank.blank?(args[:id], args[:name])
      end
    end
  end
end
