# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/perspective_view"

RSpec.describe OmnifocusMcp::Tools::Generators::PerspectiveView do
  describe ".script_path" do
    it "returns the bundled perspective view script path" do
      expect(described_class.script_path).to eq("@getPerspectiveView.js")
    end
  end

  describe ".args" do
    subject(:args) { described_class.args(perspective_name: "Today", limit: 5) }

    it "returns the perspective name and string limit" do
      expect(args).to eq(%w[Today 5])
    end
  end
end
