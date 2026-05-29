# frozen_string_literal: true

require "fast_mcp"

require_relative "mcp_envelope"
require_relative "operation_factory"
require_relative "../messages/list_tools"
require_relative "../operations/list_perspectives"
require_relative "../params"
require_relative "../presenters/list_perspectives"

module OmnifocusMcp
  module Tools
    module Definitions
      # `FastMcp::Tool` for `list_perspectives`.
      class ListPerspectivesTool < FastMcp::Tool
        tool_name "list_perspectives"
        description "List all available perspectives in OmniFocus, including built-in perspectives " \
                    "(Inbox, Projects, Tags, etc.) and custom perspectives (Pro feature)"

        arguments do
          optional(:includeBuiltIn).filled(:bool).description(
            "Include built-in perspectives (Inbox, Projects, Tags, etc.). Default: true"
          )
          optional(:includeCustom).filled(:bool).description("Include custom perspectives (Pro feature). Default: true")
        end

        extend OperationFactory

        default_operation_factory { Operations::ListPerspectives.method(:call) }

        def call(**args)
          McpEnvelope.safely("listing perspectives") do
            params = Params::ListPerspectivesParams.from_mcp(args)

            operation.call(params).fold(
              on_ok: lambda { |perspectives|
                McpEnvelope::ToolReply.success(Presenters::ListPerspectives.format(perspectives))
              },
              on_error: ->(err) { McpEnvelope::ToolReply.failure(Messages::ListTools.list_perspectives_failure(err)) }
            )
          end
        end
      end
    end
  end
end
