# frozen_string_literal: true

require "omnifocus_mcp/infrastructure/script_runner"

RSpec.describe OmnifocusMcp::Infrastructure::ScriptRunner do
  let(:success_status) { instance_double(Process::Status, success?: true, exitstatus: 0) }

  describe "#execute_jxa" do
    context "with an injected runner" do
      subject(:result) { runner.execute_jxa("JSON.stringify({ok: true})") }

      let(:runner) { described_class.new(runner: fake_runner) }
      let(:captured_argv) { [] }
      let(:fake_runner) do
        lambda do |*argv|
          captured_argv << argv
          ['{"ok":true}', "", success_status]
        end
      end

      it "returns the parsed JSON result" do
        expect(result.ok).to eq("ok" => true)
      end

      it "invokes osascript through the injected runner" do
        result

        expect(captured_argv.first[0]).to eq("osascript")
      end
    end
  end

  describe ".execute_jxa" do
    context "with the default singleton runner" do
      subject(:result) { described_class.execute_jxa("JSON.stringify({ok: true})") }

      before do
        described_class.reset!
        described_class.runner = ->(*_argv) { ['{"ok":true}', "", success_status] }
      end

      after { described_class.reset! }

      it "preserves the class-level compatibility API" do
        expect(result.ok).to eq("ok" => true)
      end
    end
  end
end
