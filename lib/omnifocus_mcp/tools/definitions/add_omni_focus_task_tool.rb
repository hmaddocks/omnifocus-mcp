# frozen_string_literal: true

require "fast_mcp"

require_relative "mcp_envelope"
require_relative "operation_factory"
require_relative "../messages/add_omnifocus_task"
require_relative "../operations/add_omnifocus_task"
require_relative "../params"

module OmnifocusMcp
  module Tools
    module Definitions
      # `FastMcp::Tool` for `add_omnifocus_task`.
      class AddOmniFocusTaskTool < FastMcp::Tool
        tool_name "add_omnifocus_task"
        description "Add a new task to OmniFocus"

        arguments do
          required(:name).filled(:string).description("The name of the task")
          optional(:note).filled(:string).description("Additional notes for the task")
          optional(:dueDate).filled(:string)
                            .description("The due date of the task in ISO format (YYYY-MM-DD or full ISO date)")
          optional(:deferDate).filled(:string)
                              .description("The defer date of the task in ISO format (YYYY-MM-DD or full ISO date)")
          optional(:plannedDate).filled(:string).description(
            "The planned date of the task in ISO format (YYYY-MM-DD or full ISO date) - " \
            "indicates intention to work on this task on this date"
          )
          optional(:flagged).filled(:bool).description("Whether the task is flagged or not")
          optional(:estimatedMinutes).filled(:integer)
                                     .description("Estimated time to complete the task, in minutes")
          optional(:tags).array(:string).description("Tags to assign to the task")
          optional(:projectName).filled(:string).description(
            "The name of the project to add the task to (will add to inbox if not specified)"
          )
          optional(:parentTaskId).filled(:string).description("ID of the parent task (preferred for accuracy)")
          optional(:parentTaskName).filled(:string).description(
            "Name of the parent task (used if ID not provided; matched within project or globally if no project)"
          )
          optional(:hierarchyLevel).filled(:integer, gteq?: 0).description(
            "Explicit level indicator for ordering in batch workflows (0=root) - ignored in single add"
          )
        end

        extend OperationFactory

        default_operation_factory { Operations::AddOmniFocusTask.method(:call) }

        def call(**args)
          McpEnvelope.safely("creating task") do
            operation.call(Params::AddTaskParams.from_mcp(args)).fold(
              on_ok: ->(created) { McpEnvelope::ToolReply.success(Messages::AddOmniFocusTask.success(args, created)) },
              on_error: ->(err) { McpEnvelope::ToolReply.failure(Messages::AddOmniFocusTask.failure(err)) }
            )
          end
        end
      end
    end
  end
end
