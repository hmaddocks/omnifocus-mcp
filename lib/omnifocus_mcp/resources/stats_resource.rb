# frozen_string_literal: true

require_relative "base"
require_relative "../tools/operations/database_stats"

module OmnifocusMcp
  module Resources
    # Quick OmniFocus database statistics overview.
    class StatsResource < Base
      uri "omnifocus://stats"
      resource_name "stats"
      description "Quick OmniFocus database statistics overview"

      def payload
        Tools::Operations::DatabaseStats.get_database_stats.fold(
          on_ok: ->(stats) { snake_case_keys(stats || {}) },
          on_error: ->(err) { { error: err } }
        )
      end
    end
  end
end
