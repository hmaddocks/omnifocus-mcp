# frozen_string_literal: true

require "omnifocus_mcp/result"
require "omnifocus_mcp/tools/operations/get_perspective_view"

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
