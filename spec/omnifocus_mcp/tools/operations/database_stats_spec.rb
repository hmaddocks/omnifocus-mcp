# frozen_string_literal: true

require "omnifocus_mcp/tools/operations/database_stats"

RSpec.describe OmnifocusMcp::Tools::Operations::DatabaseStats do
  describe ".get_database_stats" do
    subject(:result) { described_class.get_database_stats(script_runner:) }

    let(:script_runner) { QueryStackRunnerSpy.new(response: { "taskCount" => 12 }) }

    it "returns the stats payload" do
      expect(result.ok).to eq({ "taskCount" => 12 })
    end
  end

  describe ".get_changes_since" do
    subject(:result) { described_class.get_changes_since("2026-05-22T09:30:00Z", script_runner:) }

    let(:script_runner) { QueryStackRunnerSpy.new(response: { "newTasks" => [] }) }

    it "runs the changes script through the injected runner" do
      result
      expect(script_runner.sources.first).to include('new Date("2026-05-22T09:30:00Z")')
    end
  end
end
