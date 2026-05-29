# frozen_string_literal: true

require "json"

require_relative "../result"

module OmnifocusMcp
  module Parsers
    # Parses the `{"success": true|false, ...}` JSON envelope the AppleScript primitives return on stdout.
    # The block runs only on a +success: true+ envelope; it receives the parsed Hash and must itself
    # return a {OmnifocusMcp::Result} (typically wrapping a typed +Data+ payload).
    module AppleScriptEnvelope
      # Max characters of raw stdout to include in a JSON-parse error message.
      # Keeps logs/error reporters from being swamped by multi-page AppleScript dumps.
      STDOUT_PREVIEW_LIMIT = 200

      class << self
        def parse(stdout:, default_error:, &)
          parse_json(stdout).and_then { |hash| from_envelope(hash, default_error: default_error) }
                            .and_then(&)
        end

        private

        def parse_json(stdout)
          Result.ok(JSON.parse(stdout))
        rescue JSON::ParserError => e
          preview = stdout.to_s[0, STDOUT_PREVIEW_LIMIT]
          Result.error("Failed to parse AppleScript result (#{e.message}): #{preview}")
        end

        def from_envelope(parsed, default_error:)
          return Result.error(default_error) unless parsed.is_a?(Hash)

          if parsed["success"]
            Result.ok(parsed)
          else
            Result.error(parsed["error"] || default_error)
          end
        end
      end
    end
  end
end
