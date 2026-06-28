# frozen_string_literal: true

require "omnifocus_mcp/tools/operations/remove_item"

RSpec.describe OmnifocusMcp::Tools::Operations::RemoveItem do
  describe ".call" do
    subject(:result) { described_class.call({ name: "Old Task", item_type: "task" }, script_runner:) }

    let(:script_runner) { AppleScriptRunnerSpy.new(stdout: '{"success":true,"id":"abc","name":"Old Task"}') }

    it "returns the removed item" do
      expect(result.ok.name).to eq("Old Task")
    end

    it "runs generated AppleScript through the injected runner" do
      result
      expect(script_runner.scripts.first).to include("delete foundItem")
    end
  end
end
