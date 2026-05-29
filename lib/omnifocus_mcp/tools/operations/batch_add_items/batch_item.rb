# frozen_string_literal: true

require_relative "../../../result"

module OmnifocusMcp
  module Tools
    module Operations
      class BatchAddItems
        # In-flight bookkeeping for one item in a batch. The original payload
        # and its position in the input array are read-only; status and result
        # are mutated as the batch processes.
        class BatchItem
          attr_reader :payload, :index
          attr_accessor :status, :result

          def initialize(payload:, index:)
            @payload = payload
            @index = index
            @status = :pending
            @result = nil
          end

          def pending? = @status == :pending

          def fail!(message)
            @status = :failed
            @result = OmnifocusMcp::Result.error(message)
          end

          def succeed!(value)
            @status = :succeeded
            @result = OmnifocusMcp::Result.ok(value)
          end
        end
      end
    end
  end
end
