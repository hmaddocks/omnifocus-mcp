# frozen_string_literal: true

require "json"
require "open3"
require "tempfile"

require_relative "../config"
require_relative "../result"
require_relative "../utils/blank"
require_relative "js_embed"

module OmnifocusMcp
  module Infrastructure
    # Runs OmniFocus automation scripts (JXA, OmniJS, AppleScript) via
    # `osascript`.
    #
    # Instances accept an injectable runner so unit specs can supply a fake that
    # returns canned `[stdout, stderr, status]` triples without invoking
    # osascript. Class methods delegate to a default singleton for compatibility
    # with the previous `Utils::ScriptExecution` API.
    class ScriptRunner
      OMNIFOCUS_SCRIPTS_DIR = File.expand_path("../utils/omnifocus_scripts", __dir__).freeze
      STDOUT_PREVIEW_LIMIT = 200

      class << self
        def default = @default ||= new
        def reset! = @default = new

        def runner = default.runner

        def runner=(runner)
          default.runner = runner
        end

        def execute_jxa(script) = default.execute_jxa(script)
        def execute_omnifocus_source(source, args: nil) = default.execute_omnifocus_source(source, args: args)
        def execute_omnifocus_script(script_path, args: nil) = default.execute_omnifocus_script(script_path, args: args)
        def execute_applescript(source) = default.execute_applescript(source)
        def with_temp_script(content:, prefix:, ext:, &) = default.with_temp_script(content:, prefix:, ext:, &)
        def escape_content(content) = default.escape_content(content)
        def resolve_script_path(script_path) = default.resolve_script_path(script_path)
        def capture_osascript(...) = default.capture_osascript(...)
      end

      attr_writer :runner

      def initialize(runner: nil)
        @runner = runner
      end

      def runner = @runner ||= method(:capture_osascript).to_proc

      # Execute a JXA script (string source) and return {Result} with the parsed
      # JSON value.
      def execute_jxa(script)
        run_jxa_source_result(source: script, prefix: "jxa_script")
          .and_then { |stdout| parse_jxa_output(stdout) }
      end

      # Execute an OmniJS script source (string) inside OmniFocus via
      # `app.evaluateJavascript`. Returns {Result} with the parsed JSON value.
      #
      # `args` (Array<String>) is prepended as a `const argv = [...]` block
      # before the script body.
      def execute_omnifocus_source(source, args: nil)
        wrap_omnifocus_source(source:, args:).then do |wrapped|
          run_jxa_source_result(source: wrapped, prefix: "jxa_wrapper")
            .and_then { |stdout| parse_omnifocus_output(stdout) }
        end
      end

      # Execute an OmniJS script from disk inside OmniFocus.
      #
      # `script_path` may be a real filesystem path or an `@scriptName.js`
      # shorthand that resolves against `OMNIFOCUS_SCRIPTS_DIR`.
      def execute_omnifocus_script(script_path, args: nil)
        # Force UTF-8: bundled OmniJS files may contain non-ASCII bytes; the
        # platform default of US-ASCII would otherwise raise inside the
        # regex-based escape pass.
        File.read(resolve_script_path(script_path), encoding: Encoding::UTF_8).then do |source|
          execute_omnifocus_source(source, args:)
        end
      end

      # Execute a raw AppleScript source string via `osascript`.
      #
      # Returns the `[stdout, stderr, status]` triple from the runner so callers
      # can surface stderr/status without re-running the script.
      def execute_applescript(source)
        with_temp_script(content: source, prefix: "applescript", ext: "applescript") do |path|
          runner.call("osascript", path)
        end
      end

      # Materialize `content` to a tempfile, yield its path to the block, and
      # guarantee cleanup (even on exception). Uses `Tempfile.create`, which
      # removes the file when the block exits.
      def with_temp_script(content:, prefix:, ext:)
        Tempfile.create([prefix, ".#{ext}"]) do |file|
          file.write(content)
          file.flush
          yield file.path
        end
      end

      # Escape a string for safe embedding in a JXA template literal.
      def escape_content(content) = JsEmbed.template_literal(content)

      # Resolve `@scriptName.js` to an absolute path inside the gem's bundled
      # OmniJS directory. Plain paths pass through unchanged.
      def resolve_script_path(script_path)
        return script_path unless script_path.start_with?("@")

        File.join(OMNIFOCUS_SCRIPTS_DIR, script_path[1..])
      end

      # Runs `osascript` (or a test double) with an optional timeout so a hung
      # automation call cannot block the MCP server indefinitely.
      def capture_osascript(*argv)
        timeout_sec = Config.script_timeout_sec
        return Open3.capture3(*argv) unless timeout_sec

        capture_osascript_with_timeout(*argv, timeout_sec:)
      end

      private

      FailedStatus = Data.define(:exitstatus) do
        def success? = false
      end
      private_constant :FailedStatus

      SCRIPT_TIMEOUT_STATUS = FailedStatus.new(exitstatus: nil).freeze
      private_constant :SCRIPT_TIMEOUT_STATUS

      def capture_osascript_with_timeout(*argv, timeout_sec:)
        Open3.popen3(*argv) do |_stdin, stdout, stderr, wait_thr|
          out_thread = Thread.new { stdout.read }
          err_thread = Thread.new { stderr.read }

          unless wait_thr.join(timeout_sec)
            terminate_osascript(wait_thr)
            message = stderr_message(err_thread)
            message = "osascript timed out after #{timeout_sec}s" if message.empty?
            OmnifocusMcp.logger.warn("[script_execution] #{message}")
            return ["", message, SCRIPT_TIMEOUT_STATUS]
          end

          [out_thread.value, err_thread.value, wait_thr.value]
        end
      end

      def terminate_osascript(wait_thr)
        pid = wait_thr.pid
        Process.kill("TERM", pid)
        wait_thr.join(2)
        Process.kill("KILL", pid) unless wait_thr.status == false
      rescue Errno::ESRCH
        nil
      ensure
        wait_thr.join(1)
      end

      def stderr_message(err_thread)
        return "" unless err_thread.join(1)

        err_thread.value.to_s.strip
      end

      # Runs raw JXA `source` via `osascript -l JavaScript`, returning
      # {Result.ok(stdout)} on success or {Result.error} when the runner fails
      # or the process exits non-zero.
      def run_jxa_source_result(source:, prefix:)
        with_temp_script(content: source, prefix: prefix, ext: "js") do |path|
          stdout, stderr, status = runner.call("osascript", "-l", "JavaScript", path)
          return Result.error(format_run_failure(stderr, status)) unless status.success?

          OmnifocusMcp.logger.warn("[script_execution] Script stderr output: #{stderr}") if stderr && !stderr.empty?
          Result.ok(stdout)
        end
      rescue StandardError => e
        Result.error("Failed to execute script: #{e.message}")
      end

      def format_run_failure(stderr, status)
        exit_code = status.respond_to?(:exitstatus) ? status.exitstatus : status
        message = "osascript failed (exit #{exit_code})"
        message += ": #{stderr.strip}" unless stderr.nil? || stderr.empty?
        message
      end

      # Build the JXA wrapper that calls `app.evaluateJavascript` with the
      # OmniJS source embedded inside a backtick template literal.
      # rubocop:disable Metrics/MethodLength
      def wrap_omnifocus_source(source:, args:)
        script_with_args =
          if Utils::Blank.blank?(args)
            source
          else
            quoted_args = args.map { |a| %("#{escape_content(a)}") }.join(", ")
            "\n// Set up arguments\nconst argv = [#{quoted_args}];\n\n#{source}"
          end

        escaped = escape_content(script_with_args)

        <<~JXA
          function run() {
            try {
              const app = Application('OmniFocus');
              app.includeStandardAdditions = true;

              // Run the OmniJS script in OmniFocus and capture the output
              const result = app.evaluateJavascript(`#{escaped}`);

              // Return the result
              return result;
            } catch (e) {
              return JSON.stringify({ error: e.message });
            }
          }
        JXA
      end
      # rubocop:enable Metrics/MethodLength

      # JXA stdout -> {Result.ok(parsed)} or {Result.error} on parse failure.
      def parse_jxa_output(stdout)
        Result.ok(parse_json_stdout(stdout))
      rescue JSON::ParserError => e
        Result.error(parse_failure_message(parse_error: e, stdout:))
      end

      # OmniJS stdout -> {Result.ok(parsed)} or {Result.error} on parse failure.
      def parse_omnifocus_output(stdout)
        Result.ok(parse_json_stdout(stdout))
      rescue JSON::ParserError => e
        Result.error(parse_failure_message(parse_error: e, stdout:))
      end

      # osascript may return US-ASCII-labelled stdout that contains UTF-8 bytes
      # (e.g. tag names with accents). Treat stdout as UTF-8 before parsing.
      def parse_json_stdout(stdout)
        JSON.parse(stdout.to_s.dup.force_encoding(Encoding::UTF_8))
      end

      def parse_failure_message(parse_error:, stdout:)
        preview = stdout.to_s[0, STDOUT_PREVIEW_LIMIT]
        "Failed to parse script output (#{parse_error.message}): #{preview}"
      end
    end
  end
end
