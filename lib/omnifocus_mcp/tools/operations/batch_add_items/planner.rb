# frozen_string_literal: true

require_relative "../../../utils/blank"
require_relative "batch_item"
require_relative "cycle_detector"

module OmnifocusMcp
  module Tools
    module Operations
      class BatchAddItems
        # Resolves within-batch hierarchy metadata for batch add operations.
        class Planner
          Resolved = Data.define(:id, :type, :name)

          def initialize(batch_items)
            @batch_items = batch_items
            @temp_resolved = {}
          end

          def prepare!
            mark_cycle_failures(cycle_messages: cycle_detector.detect)
            mark_unknown_parent_temp_id
          end

          # Stable order: by hierarchy_level (nil -> 0), then original index.
          def processing_order
            @batch_items.sort_by { |item| [item.payload.hierarchy_level || 0, item.index] }
          end

          # @return [Array(String?, String?, Boolean)] (parent_task_id,
          #   project_name, ready). ready is false when the task depends on a
          #   parent_temp_id that has not resolved yet, signalling a deferral.
          def resolve_task_parent(payload)
            parent_task_id = payload.parent_task_id
            project_name = payload.project_name

            return [parent_task_id, project_name, true] unless need_temp_resolution?(payload)

            resolved = @temp_resolved[payload.parent_temp_id]
            return [parent_task_id, project_name, false] unless resolved

            if resolved.type == "project"
              [parent_task_id, resolved.name, true]
            else
              [resolved.id, project_name, true]
            end
          end

          def record_resolution(payload:, id:, type:)
            temp_id = payload.temp_id
            return if Utils::Blank.blank?(temp_id)

            @temp_resolved[temp_id] = Resolved.new(id: id, type: type, name: payload.name)
          end

          def finalize_unresolved!
            @batch_items.each do |item|
              next unless item.pending?

              item.fail!(unresolved_reason(item))
            end
          end

          private

          def temp_index
            @temp_index ||= @batch_items.each_with_object({}) do |item, index|
              temp = item.payload.temp_id
              index[temp] = item unless Utils::Blank.blank?(temp)
            end
          end

          def cycle_detector
            CycleDetector.new(temp_index)
          end

          def mark_cycle_failures(cycle_messages:)
            cycle_messages.each { |temp_id, message| temp_index[temp_id].fail!(message) }
          end

          def mark_unknown_parent_temp_id
            @batch_items.each do |item|
              next unless item.pending?

              parent_temp = item.payload.parent_temp_id
              next if Utils::Blank.blank?(parent_temp)
              next if temp_index.key?(parent_temp)
              next unless Utils::Blank.blank?(item.payload.parent_task_id)

              item.fail!("Unknown parentTempId: #{parent_temp}")
            end
          end

          def need_temp_resolution?(payload)
            Utils::Blank.blank?(payload.parent_task_id) &&
              !Utils::Blank.blank?(payload.parent_temp_id)
          end

          def unresolved_reason(item)
            parent_temp = item.payload.parent_temp_id
            if !Utils::Blank.blank?(parent_temp) && !@temp_resolved.key?(parent_temp)
              "Unresolved parentTempId: #{parent_temp}"
            else
              "Unresolved dependency or cycle"
            end
          end
        end
      end
    end
  end
end
