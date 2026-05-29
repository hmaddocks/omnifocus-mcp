# frozen_string_literal: true

module OmnifocusMcp
  # Runtime configuration read from the environment.
  module Config
    DEFAULT_SCRIPT_TIMEOUT_SEC = 180

    class << self
      # Seconds to wait for an `osascript` invocation before terminating it.
      # Set to 0 to disable (wait indefinitely). Default: 180.
      def script_timeout_sec
        raw = ENV.fetch("OMNIFOCUS_MCP_SCRIPT_TIMEOUT_SEC", DEFAULT_SCRIPT_TIMEOUT_SEC.to_s)
        sec = Float(raw, exception: false)
        sec&.positive? ? sec : nil
      end
    end
  end
end
