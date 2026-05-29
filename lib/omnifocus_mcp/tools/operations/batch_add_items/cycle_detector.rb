# frozen_string_literal: true

require_relative "../../../utils/blank"

module OmnifocusMcp
  module Tools
    module Operations
      class BatchAddItems
        # DFS over a temp_id -> parent_temp_id graph; collects a message for
        # every temp_id participating in any cycle.
        class CycleDetector
          # @param temp_index [Hash{String => BatchItem}]
          def initialize(temp_index)
            @temp_index = temp_index
            @visiting = Set.new
            @visited = Set.new
            @in_cycle = Set.new
            @stack = []
            @messages = {}
          end

          def detect
            @temp_index.each_key { |tid| visit(tid) }
            @messages
          end

          private

          def visit(temp_id)
            return if @visited.include?(temp_id)
            return if @in_cycle.include?(temp_id)
            return if @visiting.include?(temp_id)

            @visiting.add(temp_id)
            @stack.push(temp_id)

            parent_temp = @temp_index[temp_id].payload.parent_temp_id
            if parent_in_graph?(parent_temp)
              if @visiting.include?(parent_temp)
                record_cycle(parent_temp)
              else
                visit(parent_temp)
              end
            end

            @stack.pop
            @visiting.delete(temp_id)
            @visited.add(temp_id)
          end

          def parent_in_graph?(parent_temp)
            !Utils::Blank.blank?(parent_temp) && @temp_index.key?(parent_temp)
          end

          def record_cycle(parent_temp)
            start_idx = @stack.index(parent_temp)
            cycle_ids = @stack[start_idx..] + [parent_temp]
            path_text = cycle_ids.map { |tid| display_name(tid) }.join(" -> ")

            cycle_ids.each do |tid|
              @in_cycle.add(tid)
              @messages[tid] = "Cycle detected: #{path_text}"
            end
          end

          def display_name(temp_id)
            name = @temp_index[temp_id].payload.name.to_s
            name.empty? ? temp_id : name
          end
        end
      end
    end
  end
end
