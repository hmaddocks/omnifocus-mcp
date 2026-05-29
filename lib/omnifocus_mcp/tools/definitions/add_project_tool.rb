# frozen_string_literal: true

require "fast_mcp"

require_relative "mcp_envelope"
require_relative "operation_factory"
require_relative "../messages/add_project"
require_relative "../operations/add_project"
require_relative "../params"

module OmnifocusMcp
  module Tools
    module Definitions
      # `FastMcp::Tool` for `add_project`.
      class AddProjectTool < FastMcp::Tool
        tool_name "add_project"
        description "Add a new project to OmniFocus"

        arguments do
          required(:name).filled(:string).description("The name of the project")
          optional(:note).filled(:string).description("Additional notes for the project")
          optional(:dueDate).filled(:string)
                            .description("The due date of the project in ISO format (YYYY-MM-DD or full ISO date)")
          optional(:deferDate).filled(:string)
                              .description(
                                "The defer date of the project in ISO format (YYYY-MM-DD or full ISO date)"
                              )
          optional(:flagged).filled(:bool).description("Whether the project is flagged or not")
          optional(:estimatedMinutes).filled(:integer)
                                     .description("Estimated time to complete the project, in minutes")
          optional(:tags).array(:string).description("Tags to assign to the project")
          optional(:folderName).filled(:string).description(
            "The name of the folder to add the project to (will add to root if not specified)"
          )
          optional(:sequential).filled(:bool)
                               .description("Whether tasks in the project should be sequential (default: false)")
        end

        extend OperationFactory

        default_operation_factory { Operations::AddProject.method(:call) }

        def call(**args)
          McpEnvelope.safely("creating project") do
            operation.call(Params::AddProjectParams.from_mcp(args)).fold(
              on_ok: ->(_created) { McpEnvelope::ToolReply.success(Messages::AddProject.success(args)) },
              on_error: ->(err) { McpEnvelope::ToolReply.failure(Messages::AddProject.failure(err)) }
            )
          end
        end
      end
    end
  end
end
