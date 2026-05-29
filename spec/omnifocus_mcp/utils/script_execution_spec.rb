# frozen_string_literal: true

require "fileutils"
require "securerandom"
require "tmpdir"

require "omnifocus_mcp/utils/script_execution"

RSpec.describe OmnifocusMcp::Utils::ScriptExecution do
  let(:success_status) { instance_double(Process::Status, success?: true, exitstatus: 0) }
  let(:captured_argv) { [] }
  let(:captured_files) { {} }

  before do
    described_class.reset!
    described_class.runner = lambda { |*argv|
      captured_argv << argv
      temp_path = argv.last
      captured_files[temp_path] = File.read(temp_path) if File.exist?(temp_path)
      ['{"ok":true}', "", success_status]
    }
  end

  after { described_class.reset! }

  it "is a deprecated alias for Infrastructure::ScriptRunner" do
    expect(described_class).to equal(OmnifocusMcp::Infrastructure::ScriptRunner)
  end

  describe ".escape_content" do
    subject(:escaped_content) { described_class.escape_content(content) }

    context "with backslashes" do
      let(:content) { 'a\b' }

      it "escapes them" do
        expect(escaped_content).to eq('a\\\\b')
      end
    end

    context "with backticks" do
      let(:content) { "a`b" }

      it "escapes them" do
        expect(escaped_content).to eq('a\\`b')
      end
    end

    context "with dollar signs" do
      let(:content) { "a$b" }

      it "escapes them" do
        expect(escaped_content).to eq('a\\$b')
      end
    end

    context "with all escapable template characters" do
      let(:content) { 'a\b`c$d' }

      it "escapes them in a single pass" do
        expect(escaped_content).to eq('a\\\\b\\`c\\$d')
      end
    end

    context "with safe content" do
      let(:content) { "plain text 123 — ok" }

      it "returns it unchanged" do
        expect(escaped_content).to eq("plain text 123 — ok")
      end
    end
  end

  describe ".resolve_script_path" do
    subject(:resolved_path) { described_class.resolve_script_path(script_path) }

    context "with a plain filesystem path" do
      let(:script_path) { "/tmp/foo.js" }

      it "passes the path through unchanged" do
        expect(resolved_path).to eq("/tmp/foo.js")
      end
    end

    context "with @-prefixed shorthand" do
      let(:script_path) { "@omnifocusDump.js" }

      it "resolves against the bundled omnifocus_scripts directory" do
        expect(resolved_path).to end_with("lib/omnifocus_mcp/utils/omnifocus_scripts/omnifocusDump.js")
      end

      it "points at an existing bundled OmniJS script" do
        expect(File).to exist(resolved_path)
      end
    end
  end

  describe ".execute_jxa" do
    subject(:result) { described_class.execute_jxa(source) }

    let(:source) { "(() => 1)()" }
    let(:temp_path) do
      result
      captured_argv.first[3]
    end

    context "with a successful runner" do
      it "invokes osascript once" do
        result

        expect(captured_argv.length).to eq(1)
      end

      it "passes osascript as the executable" do
        result

        expect(captured_argv.first[0]).to eq("osascript")
      end

      it "passes the JavaScript language flags" do
        result

        expect(captured_argv.first[1..2]).to eq(["-l", "JavaScript"])
      end

      it "writes the script to a .js tempfile" do
        expect(temp_path).to be_a(String).and end_with(".js")
      end

      it "writes the supplied script body to the tempfile" do
        expect(captured_files[temp_path]).to eq(source)
      end
    end

    context "when stdout is a JSON array" do
      before do
        described_class.runner = ->(*_argv) { ["[1, 2, 3]", "", success_status] }
      end

      it "returns Result.ok with the parsed value" do
        expect(result.ok).to eq([1, 2, 3])
      end
    end

    context "when stdout is an empty JSON object" do
      before do
        described_class.runner = ->(*_argv) { ["{}", "", success_status] }
      end

      it "returns Result.ok with the parsed value" do
        expect(result.ok).to eq({})
      end
    end

    context 'when stdout matches the old "Found ... tasks" heuristic' do
      before do
        described_class.runner = ->(*_argv) { ["Found 17 tasks", "", success_status] }
      end

      it "returns a parse error instead of silently treating it as empty results" do
        expect(result.error).to match(/Failed to parse script output/)
      end

      it "includes the raw stdout preview in the parse error" do
        expect(result.error).to include("Found 17 tasks")
      end
    end

    context "when stdout is unparseable" do
      before do
        described_class.runner = ->(*_argv) { ["totally not json", "", success_status] }
      end

      it "returns a parse error" do
        expect(result.error).to match(/Failed to parse script output/)
      end
    end

    context "when osascript exits non-zero with stderr" do
      let(:failure_status) { instance_double(Process::Status, success?: false, exitstatus: 1) }

      before do
        described_class.runner = ->(*_argv) { ["", "something broke", failure_status] }
      end

      it "returns an exit error" do
        expect(result.error).to match(/osascript failed \(exit 1\)/)
      end

      it "includes stderr in the error" do
        expect(result.error).to include("something broke")
      end
    end

    context "when osascript exits non-zero without stderr" do
      let(:failure_status) { instance_double(Process::Status, success?: false, exitstatus: 2) }

      before do
        described_class.runner = ->(*_argv) { ["", "", failure_status] }
      end

      it "returns an exit-code-only error" do
        expect(result.error).to eq("osascript failed (exit 2)")
      end
    end

    context "when the runner succeeds" do
      let(:created_paths) { [] }

      before do
        described_class.runner = lambda { |*argv|
          created_paths << argv.last
          ["{}", "", success_status]
        }
      end

      it "cleans up the tempfile" do
        result

        expect(File).not_to exist(created_paths.first)
      end
    end

    context "when the runner raises" do
      let(:created_paths) { [] }

      before do
        described_class.runner = lambda { |*argv|
          created_paths << argv.last
          raise StandardError, "boom"
        }
      end

      it "cleans up the tempfile" do
        result

        expect(File).not_to exist(created_paths.first)
      end

      it "returns Result.error" do
        expect(result.error).to include("Failed to execute script: boom")
      end
    end
  end

  describe ".execute_omnifocus_source" do
    subject(:result) { described_class.execute_omnifocus_source(source, args: args) }

    let(:source) { "(() => JSON.stringify({hello: 'world'}))();" }
    let(:args) { nil }
    let(:wrapper) do
      result
      captured_files[captured_argv.first[3]]
    end

    context "with source only" do
      it "invokes osascript once" do
        result

        expect(captured_argv.length).to eq(1)
      end

      it "passes osascript with JavaScript flags" do
        result

        expect(captured_argv.first[0..2]).to eq(["osascript", "-l", "JavaScript"])
      end

      it "wraps the OmniJS source in a JXA evaluateJavascript call" do
        expect(wrapper).to include("Application('OmniFocus')")
      end

      it "embeds the OmniJS source inside evaluateJavascript" do
        expect(wrapper).to include("app.evaluateJavascript(`")
      end

      it "includes the OmniJS payload in the wrapper" do
        expect(wrapper).to include("hello:")
      end

      it "does not prepend argv" do
        expect(wrapper).not_to include("const argv =")
      end
    end

    context "with an empty args array" do
      let(:args) { [] }

      it "prepends an empty argv const" do
        expect(wrapper).to include("const argv = [];")
      end
    end

    context "with args" do
      let(:args) { ["foo", "bar baz"] }

      it "prepends an argv const" do
        expect(wrapper).to include('const argv = ["foo", "bar baz"];')
      end
    end

    context "with args containing backslashes" do
      let(:args) { ['back\slash'] }

      it "escapes them through the wrapper" do
        expect(wrapper).to include('"back\\\\\\\\slash"')
      end
    end

    context "with args containing backticks" do
      let(:args) { ["tick`"] }

      it "escapes them through the wrapper" do
        expect(wrapper).to include('"tick\\\\\\`"')
      end
    end

    context "with args containing dollar signs" do
      let(:args) { ["dollar$"] }

      it "escapes them through the wrapper" do
        expect(wrapper).to include('"dollar\\\\\\$"')
      end
    end

    context "when stdout is valid JSON" do
      before do
        described_class.runner = ->(*_argv) { ['{"count": 42}', "", success_status] }
      end

      it "returns Result.ok with the parsed value" do
        expect(result.ok).to eq("count" => 42)
      end
    end

    context "when stdout contains UTF-8 bytes labelled as US-ASCII" do
      before do
        utf8_json = '{"name":"caf\u00e9"}'.b
        described_class.runner = ->(*_argv) { [utf8_json.dup.force_encoding(Encoding::US_ASCII), "", success_status] }
      end

      it "parses the JSON as UTF-8" do
        expect(result.ok).to eq("name" => "café")
      end
    end

    context "when stdout is not JSON" do
      before do
        described_class.runner = ->(*_argv) { ["not json here", "", success_status] }
      end

      it "returns a parse error" do
        expect(result.error).to match(/Failed to parse script output/)
      end

      it "includes the raw stdout preview in the parse error" do
        expect(result.error).to include("not json here")
      end
    end

    context "when the runner succeeds" do
      let(:created_paths) { [] }

      before do
        described_class.runner = lambda { |*argv|
          created_paths << argv.last
          ["{}", "", success_status]
        }
      end

      it "cleans up the wrapper tempfile" do
        result

        expect(File).not_to exist(created_paths.first)
      end
    end

    context "when the runner raises" do
      let(:created_paths) { [] }

      before do
        described_class.runner = lambda { |*argv|
          created_paths << argv.last
          raise StandardError, "boom"
        }
      end

      it "cleans up the tempfile" do
        result

        expect(File).not_to exist(created_paths.first)
      end

      it "returns Result.error" do
        expect(result.error).to include("Failed to execute script: boom")
      end
    end
  end

  describe ".execute_omnifocus_script" do
    subject(:result) { described_class.execute_omnifocus_script(script_path) }

    context "with a filesystem path" do
      let(:script_path) { tmp_script }
      let(:tmp_script) do
        path = File.join(Dir.tmpdir, "omnifocus_mcp_test_#{SecureRandom.hex(4)}.js")
        File.write(path, "(() => JSON.stringify({hello: 'world'}))();")
        path
      end
      let(:wrapper) do
        result
        captured_files[captured_argv.first[3]]
      end

      after { FileUtils.rm_f(tmp_script) }

      it "reads the file and runs it as OmniJS source" do
        expect(wrapper).to include("hello:")
      end
    end

    context "with @-shorthand" do
      let(:script_path) { "@listTags.js" }
      let(:wrapper) do
        result
        captured_files.values.first
      end

      it "resolves against the bundled OmniJS scripts" do
        expect(wrapper).to include("Application('OmniFocus')")
      end

      it "embeds non-empty bundled script content" do
        expect(wrapper).not_to be_empty
      end
    end
  end

  describe ".execute_applescript" do
    subject(:result) { described_class.execute_applescript(source) }

    let(:source) { "display notification \"hi\"" }
    let(:temp_path) do
      result
      captured_argv.first[1]
    end

    context "with a successful runner" do
      it "invokes osascript once" do
        result

        expect(captured_argv.length).to eq(1)
      end

      it "writes the source to a .applescript tempfile" do
        expect(temp_path).to end_with(".applescript")
      end

      it "writes the supplied source to the tempfile" do
        expect(captured_files[temp_path]).to eq(source)
      end
    end

    context "when the runner returns output" do
      before do
        described_class.runner = ->(*_argv) { ["out", "err", success_status] }
      end

      it "returns the runner's [stdout, stderr, status] triple" do
        expect(result).to eq(["out", "err", success_status])
      end
    end

    context "when the runner succeeds" do
      let(:created_paths) { [] }

      before do
        described_class.runner = lambda { |*argv|
          created_paths << argv.last
          ["{}", "", success_status]
        }
      end

      it "cleans up the tempfile" do
        result

        expect(File).not_to exist(created_paths.first)
      end
    end

    context "when the runner raises" do
      let(:created_paths) { [] }

      before do
        described_class.runner = lambda { |*argv|
          created_paths << argv.last
          raise StandardError, "kaboom"
        }
      end

      it "propagates the error" do
        expect { result }.to raise_error(StandardError, "kaboom")
      end

      it "cleans up the tempfile" do
        begin
          result
        rescue StandardError
          nil
        end

        expect(File).not_to exist(created_paths.first)
      end
    end
  end

  describe ".capture_osascript" do
    around do |example|
      original = ENV.fetch("OMNIFOCUS_MCP_SCRIPT_TIMEOUT_SEC", nil)
      example.run
    ensure
      described_class.reset!
      if original.nil?
        ENV.delete("OMNIFOCUS_MCP_SCRIPT_TIMEOUT_SEC")
      else
        ENV["OMNIFOCUS_MCP_SCRIPT_TIMEOUT_SEC"] = original
      end
    end

    context "when timeout is disabled" do
      subject(:capture_result) { described_class.capture_osascript("echo", "ok") }

      let(:stdout) { capture_result[0] }
      let(:status) { capture_result[2] }

      before do
        ENV["OMNIFOCUS_MCP_SCRIPT_TIMEOUT_SEC"] = "0"
        described_class.reset!
      end

      it "delegates to Open3.capture3" do
        expect(stdout.strip).to eq("ok")
      end

      it "returns a successful status" do
        expect(status.success?).to be(true)
      end
    end

    context "when the script exceeds the timeout" do
      subject(:capture_result) { described_class.capture_osascript("sleep", "1") }

      let(:stdout) { capture_result[0] }
      let(:stderr) { capture_result[1] }
      let(:status) { capture_result[2] }

      before do
        ENV["OMNIFOCUS_MCP_SCRIPT_TIMEOUT_SEC"] = "0.1"
        described_class.reset!
      end

      it "returns empty stdout" do
        expect(stdout).to eq("")
      end

      it "returns a timeout message on stderr" do
        expect(stderr).to match(/osascript timed out after 0\.1s/)
      end

      it "returns a failed status" do
        expect(status.success?).to be(false)
      end
    end

    context "when execute_jxa receives a timeout failure" do
      subject(:result) { described_class.execute_jxa("slow") }

      let(:timeout_status) { instance_double(Process::Status, success?: false, exitstatus: nil) }

      before do
        ENV["OMNIFOCUS_MCP_SCRIPT_TIMEOUT_SEC"] = "0.1"
        described_class.reset!
        described_class.runner = lambda { |*_argv|
          ["", "osascript timed out after 0.1s", timeout_status]
        }
      end

      it "surfaces the timeout message" do
        expect(result.error).to match(/osascript timed out after 0\.1s/)
      end
    end

    context "when execute_applescript receives a timeout failure" do
      subject(:capture_result) { described_class.execute_applescript("slow") }

      let(:stdout) { capture_result[0] }
      let(:stderr) { capture_result[1] }
      let(:status) { capture_result[2] }
      let(:timeout_status) { instance_double(Process::Status, success?: false, exitstatus: nil) }

      before do
        ENV["OMNIFOCUS_MCP_SCRIPT_TIMEOUT_SEC"] = "0.1"
        described_class.reset!
        described_class.runner = lambda { |*_argv|
          ["", "osascript timed out after 0.1s", timeout_status]
        }
      end

      it "returns empty stdout" do
        expect(stdout).to eq("")
      end

      it "surfaces the timeout message" do
        expect(stderr).to match(/osascript timed out after 0\.1s/)
      end

      it "returns a failed status" do
        expect(status.success?).to be(false)
      end
    end
  end

  describe ".with_temp_script" do
    subject(:block_result) do
      described_class.with_temp_script(content: content, prefix: prefix, ext: ext) do |path|
        block.call(path)
      end
    end

    let(:content) { "hello world" }
    let(:prefix) { "wts" }
    let(:ext) { "txt" }
    let(:block) { ->(_path) { 42 } }

    it "yields an existing file containing the given content" do
      described_class.with_temp_script(content: content, prefix: prefix, ext: ext) do |path|
        expect(File.read(path)).to eq(content)
      end
    end

    it "uses the requested file extension" do
      described_class.with_temp_script(content: content, prefix: prefix, ext: ext) do |path|
        expect(path).to end_with(".txt")
      end
    end

    it "uses the requested filename prefix" do
      described_class.with_temp_script(content: content, prefix: prefix, ext: ext) do |path|
        expect(File.basename(path)).to start_with(prefix)
      end
    end

    it "cleans up the tempfile after yielding" do
      observed_path = nil
      described_class.with_temp_script(content: content, prefix: prefix, ext: ext) do |path|
        observed_path = path
      end

      expect(File).not_to exist(observed_path)
    end

    context "when the block raises" do
      let(:content) { "oops" }
      let(:observed_paths) { [] }
      let(:block) do
        lambda do |path|
          observed_paths << path
          raise "boom"
        end
      end

      it "reraises the block error" do
        expect { block_result }.to raise_error("boom")
      end

      it "removes the tempfile" do
        begin
          block_result
        rescue RuntimeError
          nil
        end

        expect(File).not_to exist(observed_paths.first)
      end
    end

    context "when the block returns a value" do
      it "returns that value" do
        expect(block_result).to eq(42)
      end
    end
  end
end
