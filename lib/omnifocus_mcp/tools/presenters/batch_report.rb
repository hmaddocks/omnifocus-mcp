# frozen_string_literal: true

module OmnifocusMcp
  module Tools
    module Presenters
      # Shared formatting for batch add/remove tool replies.
      module BatchReport
        class << self
          def format_success(past_tense:, failure_verb:, results:, items:, &detail)
            success_count = results.count(&:ok?)
            failure_count = results.count(&:error?)

            message = "✅ Successfully #{past_tense} #{success_count} items."
            message += " ⚠️ Failed to #{failure_verb} #{failure_count} items." if failure_count.positive?

            lines = results.each_with_index.map { |r, i| yield(r, items[i]) }
            "#{message}\n\n#{lines.join("\n")}"
          end

          # True when every per-item result failed (and at least one item was processed).
          def all_failed?(results) = results.any? && results.all?(&:error?)

          def format_failure(error_message, results: [], items: [], &detail)
            if results.any?
              lines = results.each_with_index.map { |r, i| yield(r, items[i]) }
              "Failed to process batch operation.\n\n#{lines.join("\n")}"
            else
              "Failed to process batch operation.\n\nNo items processed. #{error_message || ""}"
            end
          end

          def add_detail(result, original)
            item_type = original.type
            item_name = original.name
            if result.ok?
              %(- ✅ #{item_type}: "#{item_name}")
            else
              %(- ❌ #{item_type}: "#{item_name}" - Error: #{result.error || "Unknown error"})
            end
          end

          def remove_detail(result, original)
            item_type = original.item_type
            if result.ok?
              %(- ✅ #{item_type}: "#{result.ok.name}")
            else
              identifier = original.id || original.name
              "- ❌ #{item_type}: #{identifier} - Error: #{result.error}"
            end
          end
        end
      end
    end
  end
end
