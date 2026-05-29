# frozen_string_literal: true

require "omnifocus_mcp/result"
require "omnifocus_mcp/tools/operations/get_perspective_view"
require "omnifocus_mcp/tools/operations/list_perspectives"
require "omnifocus_mcp/tools/operations/list_tags"

RSpec.describe OmnifocusMcp::Tools::Operations::ListTags do
  describe ".call" do
    subject(:result) { described_class.call({ include_dropped: false }, script_runner:) }

    let(:script_runner) { ScriptRunnerSpy.new(response: { "tags" => tags }) }
    let(:tags) do
      [
        { "name" => "Active", "active" => true },
        { "name" => "Dropped", "active" => false }
      ]
    end

    it "filters dropped tags" do
      expect(result.ok.map { |tag| tag["name"] }).to eq(["Active"])
    end

    it "runs the list tags script" do
      result
      expect(script_runner.calls).to eq([["@listTags.js", nil]])
    end
  end
end

RSpec.describe OmnifocusMcp::Tools::Operations::ListPerspectives do
  describe ".call" do
    subject(:result) { described_class.call({ include_built_in: false }, script_runner:) }

    let(:script_runner) { ScriptRunnerSpy.new(response: { "perspectives" => perspectives }) }
    let(:perspectives) do
      [
        { "name" => "Inbox", "type" => "builtin" },
        { "name" => "Custom", "type" => "custom" }
      ]
    end

    it "filters built-in perspectives" do
      expect(result.ok.map { |perspective| perspective["name"] }).to eq(["Custom"])
    end
  end
end

RSpec.describe OmnifocusMcp::Tools::Operations::GetPerspectiveView do
  describe ".call" do
    subject(:result) { described_class.call({ perspective_name: "Today", limit: 1 }, script_runner:) }

    let(:script_runner) { ScriptRunnerSpy.new(response: { "items" => items }) }
    let(:items) do
      [
        { "id" => "t1", "name" => "Task 1" },
        { "id" => "t2", "name" => "Task 2" }
      ]
    end

    it "clips items to the requested limit" do
      expect(result.ok).to eq([{ "id" => "t1", "name" => "Task 1" }])
    end

    it "runs the perspective view script with generated args" do
      result
      expect(script_runner.calls).to eq([["@getPerspectiveView.js", %w[Today 1]]])
    end
  end
end

class ScriptRunnerSpy
  attr_reader :calls

  def initialize(response:)
    @response = response
    @calls = []
  end

  def execute_omnifocus_script(script_path, args: nil)
    @calls << [script_path, args]
    OmnifocusMcp::Result.ok(@response)
  end
end
