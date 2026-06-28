# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/list_perspectives"

RSpec.describe OmnifocusMcp::Tools::Generators::ListPerspectives do
  describe ".script_path" do
    it "returns the bundled list perspectives script path" do
      expect(described_class.script_path).to eq("@listPerspectives.js")
    end
  end
end
