# frozen_string_literal: true

require "fast_mcp"

require_relative "mcp_envelope"
require_relative "operation_factory"
require_relative "../messages/list_tools"
require_relative "../operations/list_tags"
require_relative "../params"
require_relative "../presenters/list_tags"

module OmnifocusMcp
  module Tools
    module Definitions
      # `FastMcp::Tool` for `list_tags`.
      class ListTagsTool < FastMcp::Tool
        tool_name "list_tags"
        description "List all tags in OmniFocus with their hierarchy. " \
                    "Useful for discovering available tags before creating or editing tasks."

        arguments do
          optional(:includeDropped).filled(:bool).description("Include dropped/inactive tags. Default: false")
        end

        extend OperationFactory

        default_operation_factory { Operations::ListTags.method(:call) }

        def call(**args)
          McpEnvelope.safely("listing tags") do
            params = Params::ListTagsParams.from_mcp(args)

            operation.call(params).fold(
              on_ok: ->(tags) { McpEnvelope::ToolReply.success(Presenters::ListTags.format(tags)) },
              on_error: ->(err) { McpEnvelope::ToolReply.failure(Messages::ListTools.list_tags_failure(err)) }
            )
          end
        end
      end
    end
  end
end
