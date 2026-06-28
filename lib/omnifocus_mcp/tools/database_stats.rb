# frozen_string_literal: true

module OmnifocusMcp
  module Tools
    # Lightweight database overview helpers that don't require pulling the
    # full OmniFocus dataset.
    #
    # Provides:
    #   * {.get_database_stats} — counts + last-modified timestamp
    #   * {.get_changes_since}  — incremental change feed since a timestamp
    module DatabaseStats
      class << self
        def get_database_stats
          require_relative "operations/database_stats"

          Operations::DatabaseStats.get_database_stats
        end

        # Incremental change feed since `since` (a Time, DateTime, or ISO string).
        #
        # @return [OmnifocusMcp::Result] +ok+ carries the changes Hash; +error+ carries a user-facing message.
        def get_changes_since(since)
          require_relative "operations/database_stats"

          Operations::DatabaseStats.get_changes_since(since)
        end
      end
    end
  end
end
