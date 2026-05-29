# frozen_string_literal: true

require_relative "../../infrastructure/script_runner"
require_relative "../../result"
require_relative "../../utils/blank"
require_relative "../generators/perspective_view"
require_relative "../params"

module OmnifocusMcp
  module Tools
    module Operations
      class GetPerspectiveView
        DEFAULT_LIMIT = 100

        class << self
          def call(params = nil, script_runner: Infrastructure::ScriptRunner, **kwargs)
            params = merge_params(params, kwargs)
            new(script_runner:).call(params)
          end

          def normalize_limit(value) = new.normalize_limit(value)

          def classify_response(response:, fields:, limit:)
            new.classify_response(response:, fields:, limit:)
          end

          def shape_items(items:, fields:, limit:)
            new.shape_items(items:, fields:, limit:)
          end

          def project_fields(items:, fields:)
            new.project_fields(items:, fields:)
          end

          private

          def merge_params(params, kwargs)
            return params || {} if kwargs.empty?

            base = params.respond_to?(:to_h) ? params.to_h : params || {}
            base.merge(kwargs)
          end
        end

        def initialize(script_runner: Infrastructure::ScriptRunner, generator: Generators::PerspectiveView)
          @script_runner = script_runner
          @generator = generator
        end

        def call(params)
          Params::McpBoundary.coerce(Params::GetPerspectiveViewParams, params).then do |params|
            perspective_name = params.perspective_name.to_s
            return OmnifocusMcp::Result.error("Perspective name is required") if Utils::Blank.blank?(perspective_name)

            limit = normalize_limit(params.limit)
            fields = params.fields
            args = generator.args(perspective_name:, limit:)

            script_runner.execute_omnifocus_script(generator.script_path, args:)
                         .and_then { |response| classify_response(response:, fields:, limit:) }
          end
        rescue StandardError => e
          OmnifocusMcp.logger.warn("[get_perspective_view] Error: #{e}")
          OmnifocusMcp::Result.error(e.message || "Unknown error occurred")
        end

        def normalize_limit(value)
          return DEFAULT_LIMIT if value.nil?
          return value if value.is_a?(Integer) && value.positive?

          DEFAULT_LIMIT
        end

        def classify_response(response:, fields:, limit:)
          shape = response.is_a?(Hash) ? response.transform_keys(&:to_sym) : nil

          case shape
          in { error: String => msg }
            OmnifocusMcp::Result.error(msg)
          in { items: Array => items }
            OmnifocusMcp::Result.ok(shape_items(items:, fields:, limit:))
          in Hash
            OmnifocusMcp::Result.ok([])
          in nil
            OmnifocusMcp::Result.error("Unexpected response from getPerspectiveView.js: #{response.inspect}")
          end
        end

        def shape_items(items:, fields:, limit:)
          items = project_fields(items:, fields:) if fields && !fields.empty?
          items = items.first(limit) if items.length > limit
          items
        end

        def project_fields(items:, fields:)
          string_fields = fields.map(&:to_s)
          items.map do |item|
            next item unless item.is_a?(Hash)

            string_fields.each_with_object({}) do |field, projected|
              projected[field] = item[field] if item.key?(field)
            end
          end
        end

        private

        attr_reader :script_runner, :generator
      end
    end
  end
end
