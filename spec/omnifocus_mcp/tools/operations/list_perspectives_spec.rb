# frozen_string_literal: true

require "omnifocus_mcp/result"
require "omnifocus_mcp/tools/operations/list_perspectives"

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
