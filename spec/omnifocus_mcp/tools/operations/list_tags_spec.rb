# frozen_string_literal: true

require "omnifocus_mcp/result"
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
