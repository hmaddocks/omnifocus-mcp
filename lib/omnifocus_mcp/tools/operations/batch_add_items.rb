# frozen_string_literal: true

require_relative "../../infrastructure/script_runner"
require_relative "../../result"
require_relative "../params"
require_relative "add_omni_focus_task"
require_relative "add_project"
require_relative "batch_add_items/planner"
require_relative "batch_add_items/batch_item"
require_relative "batch_add_items/bulk_executor"
require_relative "batch_add_items/param_builder"

module OmnifocusMcp
  module Tools
    module Operations
      class BatchAddItems
        class << self
          def call(items, add_task: Operations::AddOmniFocusTask.method(:call),
                   add_project: Operations::AddProject.method(:call),
                   execute_applescript: Infrastructure::ScriptRunner.method(:execute_applescript),
                   bulk_executor: BulkExecutor)
            new(add_task:, add_project:, execute_applescript:, bulk_executor:).call(items)
          end
        end

        def initialize(add_task:, add_project:, execute_applescript:, bulk_executor:)
          @add_task = add_task
          @add_project = add_project
          @execute_applescript = execute_applescript
          @bulk_executor = bulk_executor
        end

        def call(items)
          batch_items = Array(items).map { |item| coerce_item(item) }
                                    .then { |coerced| build_batch_items(coerced) }

          return OmnifocusMcp::Result.ok(batch_items.map(&:result)) if try_bulk_add!(batch_items:)

          planner = Planner.new(batch_items).prepare!
          process_items(ordered: planner.processing_order, planner:)
          planner.finalize_unresolved!

          OmnifocusMcp::Result.ok(batch_items.map(&:result))
        rescue StandardError => e
          OmnifocusMcp.logger.warn("[batch_add_items] Error: #{e}")
          OmnifocusMcp::Result.error(e.message || "Unknown error in batch_add_items")
        end

        private

        attr_reader :add_task, :add_project, :execute_applescript, :bulk_executor

        def try_bulk_add!(batch_items:)
          bulk_results = bulk_executor.run(batch_items, execute_applescript:)
          return false unless bulk_results

          batch_items.select(&:pending?)
                     .each_with_index do |batch_item, index|
                       apply_bulk_result(batch_item, bulk_results[index])
                     end
          true
        rescue StandardError => e
          OmnifocusMcp.logger.warn("[batch_add_items] bulk path failed (#{e.message}); falling back to sequential")
          false
        end

        def apply_bulk_result(batch_item, result)
          if result.ok?
            batch_item.succeed!(result.ok)
          else
            batch_item.fail!(result.error)
          end
        end

        def coerce_item(item)
          case item
          when Params::BatchAddItemParams then item
          when Hash then Params::BatchAddItemParams.from_hash(item)
          else raise ArgumentError, "expected BatchAddItemParams or Hash, got #{item.class}"
          end
        end

        def build_batch_items(items)
          items.each_with_index.map { |payload, index| BatchItem.new(payload:, index:) }
        end

        def process_items(ordered:, planner:)
          loop do
            pending = ordered.select(&:pending?)
            break if pending.empty?

            process_pending_items(pending:, planner:)
            break if ordered.count(&:pending?) == pending.length
          end
        end

        def process_pending_items(pending:, planner:)
          total = pending.length
          pending.each_with_index do |batch_item, index|
            OmnifocusMcp.logger.warn(
              "[batch_add_items] sequential progress #{index + 1}/#{total}: #{batch_item.payload.name}"
            )
            process_single_item(batch_item:, planner:)
          end
        end

        def process_single_item(batch_item:, planner:)
          if batch_item.payload.type.to_s == "project"
            run_project(batch_item:, planner:)
          else
            run_task(batch_item:, planner:)
          end
        rescue StandardError => e
          batch_item.fail!(e.message || "Unknown error processing item")
        end

        def run_project(batch_item:, planner:)
          payload = batch_item.payload
          project_result = add_project.call(ParamBuilder.project(payload))

          if project_result.error?
            batch_item.fail!(project_result.error)
          else
            project_id = project_result.ok.project_id
            batch_item.succeed!(project_id)
            planner.record_resolution(payload:, id: project_id, type: "project")
          end
        end

        def run_task(batch_item:, planner:)
          payload = batch_item.payload
          parent_task_id, project_name, ready = planner.resolve_task_parent(payload)
          return unless ready

          params = ParamBuilder.task(payload, parent_task_id:, project_name:)
          task_result = add_task.call(params)

          if task_result.error?
            batch_item.fail!(task_result.error)
          else
            task_id = task_result.ok.task_id
            batch_item.succeed!(task_id)
            planner.record_resolution(payload:, id: task_id, type: "task")
          end
        end
      end
    end
  end
end
