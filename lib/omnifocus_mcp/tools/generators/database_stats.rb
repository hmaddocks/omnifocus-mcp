# frozen_string_literal: true

require_relative "../database_stats"

module OmnifocusMcp
  module Tools
    module Generators
      class DatabaseStats
        class << self
          def stats_script = Tools::DatabaseStats.singleton_class.const_get(:STATS_SCRIPT)
          def changes_script(...) = Tools::DatabaseStats.changes_script(...)
        end
      end
    end
  end
end
