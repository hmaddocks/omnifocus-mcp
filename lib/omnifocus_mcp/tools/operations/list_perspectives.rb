# frozen_string_literal: true

require_relative "../../infrastructure/script_runner"
require_relative "../../result"
require_relative "../generators/list_perspectives"
require_relative "../params"

module OmnifocusMcp
  module Tools
    module Operations
      class ListPerspectives
        class << self
          def call(params = nil, script_runner: Infrastructure::ScriptRunner, **kwargs)
            merge_params(params, kwargs).then { |params| new(script_runner:).call(params) }
          end

          def classify_response(response:, include_built_in:, include_custom:)
            new.classify_response(response:, include_built_in:, include_custom:)
          end

          def filter_perspectives(perspectives:, include_built_in:, include_custom:)
            new.filter_perspectives(perspectives:, include_built_in:, include_custom:)
          end

          private

          def merge_params(params, kwargs)
            return params || {} if kwargs.empty?

            base = params.respond_to?(:to_h) ? params.to_h : params || {}
            base.merge(kwargs)
          end
        end

        def initialize(script_runner: Infrastructure::ScriptRunner, generator: Generators::ListPerspectives)
          @script_runner = script_runner
          @generator = generator
        end

        def call(params = {})
          params = Params::McpBoundary.coerce(Params::ListPerspectivesParams, params)

          script_runner.execute_omnifocus_script(generator.script_path)
                       .and_then do |response|
            classify_response(
              response:,
              include_built_in: params.include_built_in,
              include_custom: params.include_custom
            )
          end
        rescue StandardError => e
          OmnifocusMcp.logger.warn("[list_perspectives] Error: #{e}")
          OmnifocusMcp::Result.error(e.message || "Unknown error occurred")
        end

        def classify_response(response:, include_built_in:, include_custom:)
          shape = response.is_a?(Hash) ? response.transform_keys(&:to_sym) : nil

          case shape
          in { error: String => msg }
            OmnifocusMcp::Result.error(msg)
          in { perspectives: Array => perspectives }
            OmnifocusMcp::Result.ok(
              filter_perspectives(perspectives:, include_built_in:, include_custom:)
            )
          in Hash
            OmnifocusMcp::Result.ok([])
          in nil
            OmnifocusMcp::Result.error("Unexpected response from listPerspectives.js: #{response.inspect}")
          end
        end

        def filter_perspectives(perspectives:, include_built_in:, include_custom:)
          perspectives = perspectives.reject { |perspective| perspective["type"] == "builtin" } unless include_built_in
          perspectives = perspectives.reject { |perspective| perspective["type"] == "custom"  } unless include_custom
          perspectives
        end

        private

        attr_reader :script_runner, :generator
      end
    end
  end
end
