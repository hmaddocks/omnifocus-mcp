# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"

module OmnifocusMcp
  # Integration-test helpers that go through `osascript` (AppleScript) to
  # manage real OmniFocus entities. All write operations refuse to act on
  # items that don't start with `TEST_PREFIX` so the suite cannot
  # accidentally clobber real data.
  # rubocop:disable Metrics
  module IntegrationHelpers
    TEST_PREFIX = "TEST:"
    APPLE_EVENTS_DENIED_PATTERN = /Not authori[sz]ed to send Apple events to OmniFocus|\(-1743\)/i
    AUTOMATION_PERMISSION_MESSAGE = "Grant this terminal permission to control OmniFocus in " \
                                    "System Settings > Privacy & Security > Automation."

    class OmniFocusAccessError < RuntimeError; end

    module_function

    # Write `script` to a temp file and run it via `osascript`. Returns the
    # trimmed stdout. Cleans up the temp file even on failure.
    def exec_apple_script(script)
      temp_file = File.join(
        Dir.tmpdir,
        "test_omnifocus_#{(Time.now.to_f * 1000).to_i}.applescript"
      )

      begin
        File.write(temp_file, script)
        stdout, stderr, status = Open3.capture3("osascript", temp_file)
        raise_osascript_failure!(stderr, status) unless status.success?

        stdout.strip
      ensure
        FileUtils.rm_f(temp_file)
      end
    end

    # Guard rail: blocks any AppleScript mutation that doesn't target a
    # `TEST:`-prefixed name.
    def assert_test_prefix!(name)
      return if name.to_s.start_with?(TEST_PREFIX)

      raise "Safety check failed: #{name.inspect} does not start with #{TEST_PREFIX.inspect}"
    end

    # Verify that OmniFocus is running and scriptable. Raises with a
    # human-friendly message if not.
    def assert_omnifocus_running!
      result = exec_apple_script(<<~APPLESCRIPT)
        tell application "OmniFocus" to return "ok"
      APPLESCRIPT
      raise "Unexpected response from OmniFocus: #{result.inspect}" unless result.include?("ok")
    rescue OmniFocusAccessError
      raise
    rescue StandardError => e
      raise "OmniFocus is not running or not accessible. Integration tests require OmniFocus.\n#{e.message}"
    end

    def create_folder(name)
      assert_test_prefix!(name)
      escaped_name = name.gsub(/(["\\])/) { "\\#{Regexp.last_match(1)}" }
      exec_apple_script(<<~APPLESCRIPT)
        tell application "OmniFocus"
          tell front document
            set newFolder to make new folder with properties {name:"#{escaped_name}"}
            return id of newFolder as string
          end tell
        end tell
      APPLESCRIPT
    end

    # `type` is one of :task, :project, :tag, :folder.
    def resolve_item_name(id, type)
      escaped_id = id.to_s.gsub(/(["\\])/) { "\\#{Regexp.last_match(1)}" }
      singular = singular_for(type)
      begin
        result = exec_apple_script(<<~APPLESCRIPT)
          tell application "OmniFocus"
            tell front document
              set foundItem to first #{singular} whose id is "#{escaped_id}"
              return name of foundItem
            end tell
          end tell
        APPLESCRIPT
        result.empty? ? nil : result
      rescue StandardError
        nil
      end
    end

    def safe_delete_by_id(id, type)
      name = resolve_item_name(id, type)
      return false if name.nil?

      assert_test_prefix!(name)
      escaped_id = id.to_s.gsub(/(["\\])/) { "\\#{Regexp.last_match(1)}" }
      singular = singular_for(type)
      exec_apple_script(<<~APPLESCRIPT)
        tell application "OmniFocus"
          tell front document
            delete (first #{singular} whose id is "#{escaped_id}")
          end tell
        end tell
      APPLESCRIPT
      true
    end

    def find_items_by_prefix(prefix, type)
      escaped_prefix = prefix.to_s.gsub(/(["\\])/) { "\\#{Regexp.last_match(1)}" }
      collection = collection_for(type)
      result = exec_apple_script(<<~APPLESCRIPT)
        tell application "OmniFocus"
          tell front document
            set matches to {}
            repeat with anItem in #{collection}
              if name of anItem starts with "#{escaped_prefix}" then
                set end of matches to (id of anItem as string) & "|||" & name of anItem
              end if
            end repeat
            set AppleScript's text item delimiters to "\\n"
            return matches as text
          end tell
        end tell
      APPLESCRIPT

      return [] if result.empty?

      result.split("\n").reject(&:empty?).map do |line|
        id, name = line.split("|||", 2)
        { id: id, name: name }
      end
    end

    SINGULARS = {
      task: "flattened task",
      project: "flattened project",
      tag: "flattened tag",
      folder: "flattened folder"
    }.freeze

    COLLECTIONS = {
      task: "flattened tasks",
      project: "flattened projects",
      tag: "flattened tags",
      folder: "flattened folders"
    }.freeze

    def singular_for(type)
      SINGULARS.fetch(type) { raise ArgumentError, "Unknown type: #{type}" }
    end

    def collection_for(type)
      COLLECTIONS.fetch(type) { raise ArgumentError, "Unknown type: #{type}" }
    end

    def raise_osascript_failure!(stderr, status)
      message = "osascript failed (#{status.exitstatus}): #{stderr.strip}"
      raise OmniFocusAccessError, "#{message}\n#{AUTOMATION_PERMISSION_MESSAGE}" if apple_events_denied?(stderr)

      raise message
    end

    def apple_events_denied?(stderr)
      APPLE_EVENTS_DENIED_PATTERN.match?(stderr.to_s)
    end
  end
  # rubocop:enable Metrics
end
