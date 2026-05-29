# frozen_string_literal: true

module OmnifocusMcp
  module Tools
    module Definitions
      module McpEnvelope
        ToolReply = Data.define(:text, :error) do
          def to_envelope = error ? McpEnvelope.text_error(text) : McpEnvelope.text_result(text)

          def self.success(text) = new(text: text, error: false)
          def self.failure(text) = new(text: text, error: true)
        end

        class << self
          def text_result(text) = { content: [{ type: "text", text: text }] }

          def text_error(text) = { content: [{ type: "text", text: text }], isError: true }

          def safely(scope, custom_message: nil)
            result = yield
            result.is_a?(ToolReply) ? result.to_envelope : result
          rescue StandardError => e
            default = "Error #{scope}: #{e.message}"
            OmnifocusMcp.logger.warn(default)
            text_error(custom_message || default)
          end
        end
      end
    end
  end
end
