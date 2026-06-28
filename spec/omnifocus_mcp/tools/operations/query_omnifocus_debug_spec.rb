# frozen_string_literal: true

require "omnifocus_mcp/tools/operations/query_omnifocus_debug"

RSpec.describe OmnifocusMcp::Tools::Operations::QueryOmnifocusDebug do
  describe ".call" do
    subject(:result) { described_class.call("task", script_runner:) }

    let(:script_runner) { QueryStackRunnerSpy.new(response: { "entityType" => "task" }) }

    it "returns the debug payload" do
      expect(result.ok["entityType"]).to eq("task")
    end

    it "runs generated OmniFocus source through the injected runner" do
      result
      expect(script_runner.sources.first).to include('const entityType = "task"')
    end
  end
end
