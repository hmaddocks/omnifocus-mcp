# frozen_string_literal: true

require_relative "base"
require_relative "../tools/operations/query_omnifocus"

module OmnifocusMcp
  module Resources
    # Current OmniFocus inbox items.
    class InboxResource < Base
      uri "omnifocus://inbox"
      resource_name "inbox"
      description "Current OmniFocus inbox items"

      FIELDS = %w[id name flagged dueDate deferDate tagNames taskStatus note].freeze

      def payload
        OmnifocusMcp.logger.warn("[resource:inbox] Reading inbox items")

        params = Tools::Params::QueryOmnifocusParams.from_hash(
          entity: "tasks",
          filters: { inbox: true },
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
