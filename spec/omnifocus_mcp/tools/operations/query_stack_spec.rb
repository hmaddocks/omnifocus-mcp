# frozen_string_literal: true

require "omnifocus_mcp/tools/operations/database_stats"
require "omnifocus_mcp/tools/operations/query_omnifocus"
require "omnifocus_mcp/tools/operations/query_omnifocus_debug"

RSpec.describe OmnifocusMcp::Tools::Operations::QueryOmnifocus do
  describe ".call" do
    subject(:result) { described_class.call({ entity: "tasks" }, script_runner:) }

    let(:script_runner) do
      QueryStackRunnerSpy.new(response: { "items" => [{ "id" => "t1" }], "count" => 1 })
    end

    it "returns query matches" do
      expect(result.ok.items).to eq([{ "id" => "t1" }])
    end

    it "runs generated OmniFocus source through the injected runner" do
      result
      expect(script_runner.sources.first).to include("flattenedTasks")
    end
  end
end

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

class QueryStackRunnerSpy
  attr_reader :sources

  def initialize(response:)
    @response = response
    @sources = []
  end

  def execute_omnifocus_source(source, args: nil)
    @sources << source
    OmnifocusMcp::Result.ok(@response)
  end
end
