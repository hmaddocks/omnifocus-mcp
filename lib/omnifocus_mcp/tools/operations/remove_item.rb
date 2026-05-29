# frozen_string_literal: true

require_relative "../../infrastructure/script_runner"
require_relative "../../parsers/apple_script_envelope"
require_relative "../../result"
require_relative "../generators/remove_item"
require_relative "../params"

module OmnifocusMcp
  module Tools
    module Operations
      class RemoveItem
        Removed = Data.define(:id, :name)

        class << self
          def call(params = nil, script_runner: Infrastructure::ScriptRunner, **kwargs)
            merge_params(params, kwargs).then { new(script_runner:).call(it) }
          end

          def generate_apple_script(params = nil, **)
            Generators::RemoveItem.generate_apple_script(params, **)
          end

          private

          def merge_params(params, kwargs)
            return params || {} if kwargs.empty?

            base = params.respond_to?(:to_h) ? params.to_h : params || {}
            base.merge(kwargs)
          end
        end

        def initialize(script_runner: Infrastructure::ScriptRunner, generator: Generators::RemoveItem)
          @script_runner = script_runner
          @generator = generator
        end

        def call(params)
          params = Params::McpBoundary.coerce(Params::RemoveItemParams, params)
          generator.generate_apple_script(params).then { |script| run_script(script) }
        rescue StandardError => e
          OmnifocusMcp.logger.warn("[remove_item] Error: #{e}")
          OmnifocusMcp::Result.error(e.message || "Unknown error in remove_item")
        end

        private

        attr_reader :script_runner, :generator

        def run_script(script)
          stdout, stderr, status = script_runner.execute_applescript(script)

          OmnifocusMcp.logger.warn("[remove_item] AppleScript stderr: #{stderr}") if stderr && !stderr.empty?
          return OmnifocusMcp::Result.error(applescript_run_failure(stderr:, status:)) unless status.success?

          parse_result(stdout)
        end

        def parse_result(stdout)
          Parsers::AppleScriptEnvelope.parse(stdout:, default_error: "Unknown error in remove_item") do |hash|
            OmnifocusMcp::Result.ok(Removed.new(id: hash["id"], name: hash["name"]))
          end
        end

        def applescript_run_failure(stderr:, status:)
          exit_code = status.respond_to?(:exitstatus) ? status.exitstatus : status
          message = "osascript failed (exit #{exit_code})"
          message += ": #{stderr.strip}" unless stderr.nil? || stderr.empty?
          message
        end
      end
    end
  end
end
