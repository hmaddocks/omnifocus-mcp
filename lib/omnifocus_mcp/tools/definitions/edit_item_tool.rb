# frozen_string_literal: true

require "fast_mcp"

require_relative "mcp_envelope"
require_relative "operation_factory"
require_relative "../messages/edit_item"
require_relative "../operations/edit_item"
require_relative "../params"
require_relative "../../utils/blank"

module OmnifocusMcp
  module Tools
    module Definitions
      # `FastMcp::Tool` for `edit_item`.
      class EditItemTool < FastMcp::Tool
        tool_name "edit_item"
        description "Edit a task or project in OmniFocus"

        # rubocop:disable Metrics/BlockLength
        arguments do
          optional(:id).filled(:string).description("The ID of the task or project to edit")
          optional(:name).filled(:string)
                         .description("The name of the task or project to edit (as fallback if ID not provided)")
          required(:itemType).filled(included_in?: %w[task project])
                             .description("Type of item to edit ('task' or 'project')")

          optional(:newName).filled(:string).description("New name for the item")
          optional(:newNote).filled(:string).description("New note for the item")
          optional(:newDueDate).maybe(:string).description(
            "New due date in ISO format (YYYY-MM-DD or full ISO date); set to empty string to clear"
          )
          optional(:newDeferDate).maybe(:string).description(
            "New defer date in ISO format (YYYY-MM-DD or full ISO date); set to empty string to clear"
          )
          optional(:newPlannedDate).maybe(:string).description(
            "New planned date in ISO format (YYYY-MM-DD or full ISO date); set to empty string to clear (tasks only)"
          )
          optional(:newFlagged).filled(:bool)
                               .description("Set flagged status (set to false for no flag, true for flag)")
          optional(:newEstimatedMinutes).filled(:integer).description("New estimated minutes")

          optional(:newStatus).filled(included_in?: %w[incomplete completed dropped skipped]).description(
            "New status for tasks (incomplete, completed, dropped, skipped). 'skipped' only works on " \
            "repeating tasks \u2014 it completes the current occurrence to trigger the next repeat, then " \
            "drops the completed instance."
          )
          optional(:addTags).array(:string).description("Tags to add to the task")
          optional(:removeTags).array(:string).description("Tags to remove from the task")
          optional(:replaceTags).array(:string).description("Tags to replace all existing tags with")
          optional(:newProjectName).maybe(:string).description(
            "Move this task to a different project by name or folder path (e.g. 'My Project' or " \
            "'Work/My Project' to disambiguate). Pass an empty string or 'inbox' to move the task to " \
            "the inbox. (tasks only)"
          )

          optional(:newSequential).filled(:bool).description("Whether the project should be sequential")
          optional(:newFolderName).filled(:string).description("New folder to move the project to")
          optional(:newProjectStatus).filled(included_in?: %w[active completed dropped onHold])
                                     .description("New status for projects")
        end
        # rubocop:enable Metrics/BlockLength

        extend OperationFactory

        default_operation_factory { Operations::EditItem.method(:call) }

        def call(**args)
          if missing_identifier?(args)
            return McpEnvelope::ToolReply.failure(Messages::EditItem.missing_identifier).to_envelope
          end

          McpEnvelope.safely("updating #{args[:itemType]}") do
            operation.call(Params::EditItemParams.from_mcp(args)).fold(
              on_ok: ->(edited) { McpEnvelope::ToolReply.success(Messages::EditItem.success(args, edited)) },
              on_error: ->(err) { McpEnvelope::ToolReply.failure(Messages::EditItem.failure(args, err)) }
            )
          end
        end

        private

        def missing_identifier?(args) = Utils::Blank.blank?(args[:id], args[:name])
      end
    end
  end
end
