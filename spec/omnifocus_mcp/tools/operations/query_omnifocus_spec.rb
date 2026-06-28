# frozen_string_literal: true

require "omnifocus_mcp/tools/operations/query_omnifocus"

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
