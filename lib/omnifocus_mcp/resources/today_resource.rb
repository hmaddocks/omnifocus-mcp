# frozen_string_literal: true

require_relative "base"
require_relative "../tools/operations/query_omnifocus"

module OmnifocusMcp
  module Resources
    class TodayResource < Base
      uri "omnifocus://today"
      resource_name "today"
      description "Today's agenda — tasks due today, planned for today, and overdue items"

      DUE_FIELDS     = %w[id name flagged dueDate projectName tagNames taskStatus].freeze
      PLANNED_FIELDS = %w[id name flagged plannedDate projectName tagNames taskStatus].freeze
      OVERDUE_FIELDS = DUE_FIELDS

      def payload
        OmnifocusMcp.logger.warn("[resource:today] Reading today's agenda")

        {
          due_today: items_or_empty(query(filters: { due_on: 0 }, fields: DUE_FIELDS)),
          planned_today: items_or_empty(query(filters: { planned_on: 0 }, fields: PLANNED_FIELDS)),
          overdue: items_or_empty(query(filters: { status: ["Overdue"] }, fields: OVERDUE_FIELDS))
        }
      end

      private

      def query(filters:, fields:)
        params = Tools::Params::QueryOmnifocusParams.from_hash(
          entity: "tasks", filters: filters, fields: fields
        )
        Tools::Operations::QueryOmnifocus.call(params)
      end
    end
  end
end
