# frozen_string_literal: true

require_relative "../../infrastructure/script_runner"
require_relative "../../parsers/apple_script_envelope"
require_relative "../../result"
require_relative "../generators/add_omni_focus_task"
require_relative "../params"

module OmnifocusMcp
  module Tools
    module Operations
      class AddOmniFocusTask
        Created = Generators::AddOmniFocusTask::Created

        class << self
          def call(params = nil, script_runner: Infrastructure::ScriptRunner, **kwargs)
            merge_params(params, kwargs).then { new(script_runner:).call(it) }
          end

          def generate_apple_script(...) = Generators::AddOmniFocusTask.generate_apple_script(...)
          def generate_bulk_apple_script(...) = Generators::AddOmniFocusTask.generate_bulk_apple_script(...)

          private

          def merge_params(params, kwargs)
            return params || {} if kwargs.empty?

            base = params.respond_to?(:to_h) ? params.to_h : params || {}
            base.merge(kwargs)
          end
        end

        def initialize(script_runner: Infrastructure::ScriptRunner, generator: Generators::AddOmniFocusTask)
          @script_runner = script_runner
          @generator = generator
        end

        def call(params)
          params = Params::McpBoundary.coerce(Params::AddTaskParams, params)
          generator.generate_apple_script(params).then { |script| run_script(script) }
        rescue StandardError => e
          OmnifocusMcp.logger.warn("[add_omnifocus_task] Error: #{e}")
          OmnifocusMcp::Result.error(e.message || "Unknown error in add_omnifocus_task")
        end

        private

        attr_reader :script_runner, :generator

        def run_script(script)
          stdout, stderr, status = script_runner.execute_applescript(script)

          OmnifocusMcp.logger.warn("[add_omnifocus_task] AppleScript stderr: #{stderr}") if stderr && !stderr.empty?
          return OmnifocusMcp::Result.error(applescript_run_failure(stderr:, status:)) unless status.success?

          parse_result(stdout)
        end

        def parse_result(stdout)
          Parsers::AppleScriptEnvelope.parse(stdout:, default_error: "Unknown error in add_omnifocus_task") do |hash|
            OmnifocusMcp::Result.ok(Created.new(task_id: hash["taskId"], placement: hash["placement"]))
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
