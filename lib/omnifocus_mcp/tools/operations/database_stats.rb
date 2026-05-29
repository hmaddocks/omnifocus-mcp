# frozen_string_literal: true

require_relative "../../infrastructure/script_runner"
require_relative "../../result"
require_relative "../generators/database_stats"

module OmnifocusMcp
  module Tools
    module Operations
      class DatabaseStats
        class << self
          def get_database_stats(script_runner: Infrastructure::ScriptRunner)
            new(script_runner:).get_database_stats
          end

          def get_changes_since(since, script_runner: Infrastructure::ScriptRunner)
            new(script_runner:).get_changes_since(since)
          end
        end

        def initialize(script_runner: Infrastructure::ScriptRunner, generator: Generators::DatabaseStats)
          @script_runner = script_runner
          @generator = generator
        end

        def get_database_stats
          script_payload_result(script_runner.execute_omnifocus_source(generator.stats_script))
        end

        def get_changes_since(since)
          iso = since.respond_to?(:utc) ? since.utc.iso8601 : since.to_s

          script_payload_result(script_runner.execute_omnifocus_source(generator.changes_script(iso)))
        end

        private

        attr_reader :script_runner, :generator

        def script_payload_result(execution)
          execution.and_then do |payload|
            if payload.is_a?(Hash) && payload["error"]
              Result.error(payload["error"])
            else
              Result.ok(payload)
            end
          end
        end
      end
    end
  end
end
