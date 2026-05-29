# frozen_string_literal: true

require_relative "../../infrastructure/script_runner"
require_relative "../../result"
require_relative "../generators/query_omnifocus"
require_relative "../params"

module OmnifocusMcp
  module Tools
    module Operations
      class QueryOmnifocus
        Match = Data.define(:items, :count)

        class << self
          def call(params = nil, script_runner: Infrastructure::ScriptRunner, **kwargs)
            merge_params(params, kwargs).then { new(script_runner:).call(it) }
          end

          def classify_response(...) = new.classify_response(...)
          def build_match(...) = new.build_match(...)
          def generate_query_script(...) = Generators::QueryOmnifocus.generate_query_script(...)

          private

          def merge_params(params, kwargs)
            return params || {} if kwargs.empty?

            base = params.respond_to?(:to_h) ? params.to_h : params || {}
            base.merge(kwargs)
          end
        end

        def initialize(script_runner: Infrastructure::ScriptRunner, generator: Generators::QueryOmnifocus)
          @script_runner = script_runner
          @generator = generator
        end

        def call(params)
          params = Params::McpBoundary.coerce(Params::QueryOmnifocusParams, params)
          generator.generate_query_script(params).then do |script|
            script_runner.execute_omnifocus_source(script)
                         .and_then { |response| classify_response(response:, summary: params.summary == true) }
          end
        rescue StandardError => e
          OmnifocusMcp.logger.warn("[query_omnifocus] Error: #{e}")
          OmnifocusMcp::Result.error(e.message || "Unknown error occurred")
        end

        def classify_response(response:, summary:)
          shape = response.is_a?(Hash) ? response.transform_keys(&:to_sym) : nil

          case shape
          in { error: String => msg }
            OmnifocusMcp::Result.error(msg)
          in { items: Array => items, count: Integer => count }
            OmnifocusMcp::Result.ok(build_match(items:, count:, summary: summary))
          in { count: Integer => count }
            OmnifocusMcp::Result.ok(Match.new(items: nil, count: count))
          in Hash
            OmnifocusMcp::Result.ok(Match.new(items: nil, count: nil))
          in nil
            OmnifocusMcp::Result.error("Unexpected response from queryOmnifocus: #{response.inspect}")
          end
        end

        def build_match(items:, count:, summary:) = Match.new(items: summary ? nil : items, count: count)

        private

        attr_reader :script_runner, :generator
      end
    end
  end
end
