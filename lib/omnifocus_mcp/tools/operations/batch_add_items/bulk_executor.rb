# frozen_string_literal: true

require_relative "../../../parsers/apple_script_envelope"
require_relative "../../../infrastructure/script_runner"
require_relative "../../../utils/blank"
require_relative "../../../result"
require_relative "../../generators/add_omni_focus_task"
require_relative "param_builder"

module OmnifocusMcp
  module Tools
    module Operations
      class BatchAddItems
        # Runs eligible batch adds in a single osascript invocation instead of
        # one process per item. Large MCP batches (20+ tasks) were timing out
        # when each item spawned its own osascript call.
        module BulkExecutor
          # Independent task batches at or above this size use one osascript call.
          BULK_MIN_ITEMS = 2

          class << self
            # @param batch_items [Array<BatchItem>] only pending items are executed
            # @return [Array<OmnifocusMcp::Result>, nil] per-item results in pending
            #   order, or +nil+ when bulk is not eligible or the script fails
            def run(batch_items, execute_applescript: Infrastructure::ScriptRunner.method(:execute_applescript))
              pending = batch_items.select(&:pending?)
              return nil unless eligible?(pending)

              params_list = pending.map do |bi|
                ParamBuilder.task(bi.payload, parent_task_id: nil, project_name: bi.payload.project_name)
              end
              script = Generators::AddOmniFocusTask.generate_bulk_apple_script(params_list)

              stdout, stderr, status = execute_applescript.call(script)
              log_stderr(stderr)

              return nil unless status.success?

              parse_bulk_results(stdout, expected_count: pending.length)
            end

            def eligible?(batch_items)
              return false if batch_items.length < BULK_MIN_ITEMS

              batch_items.all? { |bi| bi.payload.type.to_s == "task" } &&
                batch_items.none? { |bi| needs_sequential_resolution?(bi.payload) }
            end

            def needs_sequential_resolution?(payload)
              [
                payload.parent_temp_id,
                payload.parent_task_id,
                payload.parent_task_name
              ].any? { !Utils::Blank.blank?(it) }
            end

            private

            def log_stderr(stderr)
              return if stderr.nil? || stderr.empty?

              OmnifocusMcp.logger.warn("[batch_add_items] AppleScript stderr: #{stderr}")
            end

            def parse_bulk_results(stdout, expected_count:)
              parsed = Parsers::AppleScriptEnvelope.parse(
                stdout:,
                default_error: "Unknown error in batch_add_items bulk add"
              ) do |hash|
                items = hash["items"]
                unless items.is_a?(Array) && items.length == expected_count
                  next OmnifocusMcp::Result.error("item count mismatch")
                end

                results = items.map { |item| parse_bulk_item(item) }
                results.find(&:error?) || OmnifocusMcp::Result.ok(results)
              end

              parsed.error? ? nil : parsed.ok
            end

            def parse_bulk_item(item)
              unless item.is_a?(Hash) && item["taskId"]
                return OmnifocusMcp::Result.error("Missing taskId in bulk response")
              end

              OmnifocusMcp::Result.ok(item["taskId"])
            end
          end
        end
      end
    end
  end
end
