# frozen_string_literal: true

require_relative "../../infrastructure/script_runner"
require_relative "../../result"
require_relative "../generators/list_tags"
require_relative "../params"

module OmnifocusMcp
  module Tools
    module Operations
      class ListTags
        class << self
          def call(params = nil, script_runner: Infrastructure::ScriptRunner, **kwargs)
            params = merge_params(params, kwargs)
            new(script_runner:).call(params)
          end

          def classify_response(response:, include_dropped:)
            new.classify_response(response:, include_dropped:)
          end

          def filter_tags(tags:, include_dropped:)
            new.filter_tags(tags:, include_dropped:)
          end

          private

          def merge_params(params, kwargs)
            return params || {} if kwargs.empty?

            base = params.respond_to?(:to_h) ? params.to_h : params || {}
            base.merge(kwargs)
          end
        end

        def initialize(script_runner: Infrastructure::ScriptRunner, generator: Generators::ListTags)
          @script_runner = script_runner
          @generator = generator
        end

        def call(params = {})
          params = Params::McpBoundary.coerce(Params::ListTagsParams, params)

          script_runner.execute_omnifocus_script(generator.script_path)
                       .and_then do |response|
            classify_response(response:, include_dropped: params.include_dropped)
          end
        rescue StandardError => e
          OmnifocusMcp.logger.warn("[list_tags] Error: #{e}")
          OmnifocusMcp::Result.error(e.message || "Unknown error occurred")
        end

        def classify_response(response:, include_dropped:)
          shape = response.is_a?(Hash) ? response.transform_keys(&:to_sym) : nil

          case shape
          in { error: String => msg }
            OmnifocusMcp::Result.error(msg)
          in { tags: Array => tags }
            OmnifocusMcp::Result.ok(filter_tags(tags:, include_dropped:))
          in Hash
            OmnifocusMcp::Result.ok([])
          in nil
            OmnifocusMcp::Result.error("Unexpected response from listTags.js: #{response.inspect}")
          end
        end

        def filter_tags(tags:, include_dropped:)
          return tags if include_dropped

          tags.select { |tag| tag["active"] }
        end

        private

        attr_reader :script_runner, :generator
      end
    end
  end
end
