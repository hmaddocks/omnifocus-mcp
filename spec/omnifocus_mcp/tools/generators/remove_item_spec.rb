# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/remove_item"

RSpec.describe OmnifocusMcp::Tools::Generators::RemoveItem do
  describe ".generate_apple_script" do
    subject(:script) { described_class.generate_apple_script(name: "Old Task", item_type: "task") }

    it "finds the item by name" do
      expect(script).to include(%(first flattened task whose name is "Old Task"))
    end

    it "deletes the found item" do
      expect(script).to include("delete foundItem")
    end
  end
end
