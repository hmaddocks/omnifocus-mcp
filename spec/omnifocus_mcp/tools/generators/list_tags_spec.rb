# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/list_tags"

RSpec.describe OmnifocusMcp::Tools::Generators::ListTags do
  describe ".script_path" do
    it "returns the bundled list tags script path" do
      expect(described_class.script_path).to eq("@listTags.js")
    end
  end
end
