# frozen_string_literal: true

require_relative "../../result"
require_relative "../params"
require_relative "remove_item"

module OmnifocusMcp
  module Tools
    module Operations
      class BatchRemoveItems
        class << self
          def call(items, remove: Operations::RemoveItem.method(:call))
            new(remove:).call(items)
          end
        end

        def initialize(remove:)
          @remove = remove
        end

        def call(items)
          Array(items).map { |item| remove_one(coerce_item(item)) }
                      .then { |results| OmnifocusMcp::Result.ok(results) }
        rescue StandardError => e
          OmnifocusMcp.logger.warn("[batch_remove_items] Error: #{e}")
          OmnifocusMcp::Result.error(e.message || "Unknown error in batch_remove_items")
        end

        private

        attr_reader :remove

        def coerce_item(item)
          case item
          when Params::BatchRemoveItemParams
            item
          when Hash
            Params::BatchRemoveItemParams.from_hash(item)
          else raise ArgumentError, "expected BatchRemoveItemParams or Hash, got #{item.class}"
          end
        end

        def remove_one(item)
          remove.call(item)
        rescue StandardError => e
          OmnifocusMcp::Result.error(e.message || "Unknown error processing item")
        end
      end
    end
  end
end
