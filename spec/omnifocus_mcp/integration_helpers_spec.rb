# frozen_string_literal: true

require_relative "../integration/helpers"

RSpec.describe OmnifocusMcp::IntegrationHelpers do
  describe ".exec_apple_script" do
    subject(:exec_script) { described_class.exec_apple_script("tell application \"OmniFocus\" to return \"ok\"") }

    let(:status) { instance_double(Process::Status, success?: success, exitstatus: 1) }

    before do
      allow(Open3).to receive(:capture3).and_return([stdout, stderr, status])
    end

    context "when osascript succeeds" do
      let(:success) { true }
      let(:stdout) { "ok\n" }
      let(:stderr) { "" }

      it "returns trimmed stdout" do
        expect(exec_script).to eq("ok")
      end
    end

    context "when macOS denies Apple Events authorization" do
      let(:success) { false }
      let(:stdout) { "" }
      let(:stderr) { "execution error: Not authorised to send Apple events to OmniFocus. (-1743)" }

      it "raises an OmniFocus access error with remediation guidance" do
        expect { exec_script }.to raise_error(
          described_class::OmniFocusAccessError,
          /System Settings > Privacy & Security > Automation/
        )
      end
    end

    context "when osascript fails for another reason" do
      let(:success) { false }
      let(:stdout) { "" }
      let(:stderr) { "syntax error" }

      it "raises a generic runtime error" do
        expect { exec_script }.to raise_error(RuntimeError, /osascript failed \(1\): syntax error/)
      end
    end
  end

  describe ".assert_omnifocus_running!" do
    subject(:assert_running) { described_class.assert_omnifocus_running! }

    before do
      allow(described_class).to receive(:exec_apple_script).and_raise(
        described_class::OmniFocusAccessError,
        "denied"
      )
    end

    it "preserves OmniFocus access errors for RSpec skip handling" do
      expect { assert_running }.to raise_error(described_class::OmniFocusAccessError, "denied")
    end
  end
end
