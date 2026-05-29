# frozen_string_literal: true

require_relative "../../infrastructure/script_runner"
require_relative "../../result"
require_relative "../generators/query_omnifocus_debug"

module OmnifocusMcp
  module Tools
    module Operations
      class QueryOmnifocusDebug
        ENTITIES = %w[task project folder].freeze
        private_constant :ENTITIES

        class << self
          def call(entity, script_runner: Infrastructure::ScriptRunner)
            new(script_runner:).call(entity)
          end

          def generate_debug_script(...) = Generators::QueryOmnifocusDebug.generate_debug_script(...)
        end

        def initialize(script_runner: Infrastructure::ScriptRunner, generator: Generators::QueryOmnifocusDebug)
          @script_runner = script_runner
          @generator = generator
        end

        def call(entity)
          normalized = entity.to_s
          return OmnifocusMcp::Result.error(unknown_entity_message(normalized)) unless ENTITIES.include?(normalized)

          generator.generate_debug_script(normalized).then do |script|
            script_runner.execute_omnifocus_source(script)
                         .and_then { |response| classify_response(response) }
          end
        rescue StandardError => e
          OmnifocusMcp.logger.warn("[query_omnifocus_debug] Error: #{e}")
          OmnifocusMcp::Result.error(e.message || "Unknown error in query_omnifocus_debug")
        end

        private

        attr_reader :script_runner, :generator

        def classify_response(response)
          shape = response.is_a?(Hash) ? response.transform_keys(&:to_sym) : nil

          case shape
          in { error: String => msg }
            OmnifocusMcp::Result.error(msg)
          in Hash
            OmnifocusMcp::Result.ok(response)
          in nil
            OmnifocusMcp::Result.error("Unexpected response from query_omnifocus_debug: #{response.inspect}")
          end
        end

        def unknown_entity_message(entity)
          "Unknown entity: #{entity.inspect}. Must be one of #{ENTITIES.join(", ")}"
        end
      end
    end
  end
end
