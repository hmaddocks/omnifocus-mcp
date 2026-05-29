# frozen_string_literal: true

require "fast_mcp"

require_relative "mcp_envelope"
require_relative "operation_factory"
require_relative "../messages/list_tools"
require_relative "../operations/get_perspective_view"
require_relative "../params"
require_relative "../presenters/perspective_view"

module OmnifocusMcp
  module Tools
    module Definitions
      # `FastMcp::Tool` for `get_perspective_view`.
      class GetPerspectiveViewTool < FastMcp::Tool
        tool_name "get_perspective_view"
        description "Get the items visible in a specific OmniFocus perspective. " \
                    "Shows what tasks and projects are displayed when viewing that perspective"

        arguments do
          required(:perspectiveName).filled(:string).description(
            "Name of the perspective to view (e.g., 'Inbox', 'Projects', 'Flagged', or custom perspective name)"
          )
          optional(:limit).filled(:integer).description("Maximum number of items to return. Default: 100")
          optional(:fields).array(:string).description(
            "Specific fields to include in the response. Reduces response size. Available fields: " \
            "id, name, note, flagged, dueDate, deferDate, completionDate, taskStatus, projectName, " \
            "tagNames, estimatedMinutes"
          )
        end

        extend OperationFactory

        default_operation_factory { Operations::GetPerspectiveView.method(:call) }

        def call(**args)
          McpEnvelope.safely("getting perspective view") do
            params = Params::GetPerspectiveViewParams.from_mcp(args)
            limit = Operations::GetPerspectiveView.normalize_limit(params.limit)
            # TODO: I don't like this nested function call
            operation.call(
              Params::GetPerspectiveViewParams.new(
                perspective_name: params.perspective_name, limit: limit, fields: params.fields
              )
            ).fold(
              on_ok: lambda do |items|
                McpEnvelope::ToolReply.success(Presenters::PerspectiveView.format(args[:perspectiveName], items, limit))
              end,
              on_error: ->(err) { McpEnvelope::ToolReply.failure(Messages::ListTools.perspective_view_failure(err)) }
            )
          end
        end
      end
    end
  end
end
