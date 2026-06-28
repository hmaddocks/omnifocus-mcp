# frozen_string_literal: true

require "omnifocus_mcp/tools/operations/add_project"

RSpec.describe OmnifocusMcp::Tools::Operations::AddProject do
  describe ".call" do
    subject(:result) { described_class.call({ name: "Test Project" }, script_runner:) }

    let(:script_runner) { AppleScriptRunnerSpy.new(stdout: '{"success":true,"projectId":"proj-1"}') }

    it "returns the created project id" do
      expect(result.ok.project_id).to eq("proj-1")
    end

    it "runs generated AppleScript through the injected runner" do
      result
      expect(script_runner.scripts.first).to include(%(make new project with properties {name:"Test Project"}))
    end
  end
end
