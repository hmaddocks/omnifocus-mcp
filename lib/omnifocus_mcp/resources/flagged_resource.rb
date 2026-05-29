# frozen_string_literal: true

require_relative "base"
require_relative "../tools/operations/query_omnifocus"

module OmnifocusMcp
  module Resources
    # All flagged OmniFocus items.
    class FlaggedResource < Base
      uri "omnifocus://flagged"
      resource_name "flagged"
      description "All flagged OmniFocus items"

      FIELDS = %w[id name dueDate projectName tagNames taskStatus].freeze

      def payload
        OmnifocusMcp.logger.warn("[resource:flagged] Reading flagged items")

        params = Tools::Params::QueryOmnifocusParams.from_hash(
          entity: "tasks",
          filters: { flagged: true },
          fields: FIELDS
        )
        Tools::Operations::QueryOmnifocus.call(params).fold(
          on_ok: ->(match) { snake_case_keys(match.items || []) },
          on_error: ->(err) { { error: err } }
        )
      end
    end
  end
end
