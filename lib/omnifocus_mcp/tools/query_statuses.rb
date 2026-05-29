# frozen_string_literal: true

module OmnifocusMcp
  module Tools
    # Valid status filter values for `query_omnifocus`, shared by the MCP schema,
    # generated OmniJS, and specs.
    module QueryStatuses
      TASK = %w[Next Available Blocked DueSoon Overdue Completed Dropped].freeze
      PROJECT = %w[Active OnHold Done Dropped].freeze

      class << self
        def task_list_for_schema
          TASK.map { |s| "'#{s}'" }.join(", ")
        end

        def project_list_for_schema
          PROJECT.map { |s| "'#{s}'" }.join(", ")
        end
      end
    end
  end
end
