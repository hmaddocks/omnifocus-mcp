# frozen_string_literal: true

# Cursor's MCP client rejects JSON-RPC error responses with `"id": null`
# (fast-mcp 1.6 emits null when the request id is unknown). Coerce those to 0
# and ignore blank stdin lines so empty writes do not produce invalid responses.
module OmnifocusMcp
  module JsonRpcCompat
    UNKNOWN_REQUEST_ID = 0

    module_function

    def apply!
      $stdin.set_encoding(Encoding::UTF_8) if $stdin.respond_to?(:set_encoding)
      patch_server_send_error!
      patch_stdio_transport!
    end

    def normalize_id(id) = id.nil? ? UNKNOWN_REQUEST_ID : id

    # MCP clients send UTF-8 JSON, but stdio may be US-ASCII-labelled (same as
    # osascript stdout in ScriptRunner). Re-label before strip/parse.
    def normalize_line(line) = line.to_s.dup.force_encoding(Encoding::UTF_8).strip

    def patch_server_send_error!
      return if server_send_error_patched?

      FastMcp::Server.class_eval do
        alias_method :send_error_without_json_rpc_compat, :send_error

        def send_error(code, message, id = nil)
          send_error_without_json_rpc_compat(code, message, OmnifocusMcp::JsonRpcCompat.normalize_id(id))
        end
      end
    end
    private_class_method :patch_server_send_error!

    # rubocop:disable Metrics
    def patch_stdio_transport!
      return if stdio_transport_patched?

      FastMcp::Transports::StdioTransport.class_eval do
        alias_method :start_without_json_rpc_compat, :start

        def start
          @logger.info("Starting STDIO transport")
          @running = true

          while @running && (line = $stdin.gets)
            stripped = OmnifocusMcp::JsonRpcCompat.normalize_line(line)
            next if stripped.empty?

            begin
              process_message(stripped)
            rescue StandardError => e
              @logger.error("Error processing message: #{e.message}")
              @logger.error(e.backtrace.join("\n"))
              send_error(-32_000, "Internal error: #{e.message}")
            end
          end
        end

        alias_method :send_error_without_json_rpc_compat, :send_error

        def send_error(code, message, id = nil)
          send_error_without_json_rpc_compat(code, message, OmnifocusMcp::JsonRpcCompat.normalize_id(id))
        end
      end
    end
    # rubocop:enable Metrics
    private_class_method :patch_stdio_transport!

    def server_send_error_patched?
      FastMcp::Server.private_method_defined?(:send_error_without_json_rpc_compat)
    end
    private_class_method :server_send_error_patched?

    def stdio_transport_patched?
      FastMcp::Transports::StdioTransport.private_method_defined?(:start_without_json_rpc_compat)
    end
    private_class_method :stdio_transport_patched?
  end
end
