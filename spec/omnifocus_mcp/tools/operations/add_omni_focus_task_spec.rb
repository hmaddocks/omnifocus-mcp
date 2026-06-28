# frozen_string_literal: true

require "omnifocus_mcp/tools/operations/add_omni_focus_task"

RSpec.describe OmnifocusMcp::Tools::Operations::AddOmniFocusTask do
  describe ".call" do
    subject(:result) { described_class.call({ name: "Buy milk" }, script_runner:) }

    let(:script_runner) do
      AppleScriptRunnerSpy.new(stdout: '{"success":true,"taskId":"abc","placement":"inbox"}')
    end

    it "returns the created task id" do
      expect(result.ok.task_id).to eq("abc")
    end

    it "runs generated AppleScript through the injected runner" do
      result
      expect(script_runner.scripts.first).to include(%(make new inbox task with properties {name:"Buy milk"}))
    end
  end
end
