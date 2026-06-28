# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/edit_item"

RSpec.describe OmnifocusMcp::Tools::Generators::EditItem do
  describe ".generate_apple_script" do
    subject(:script) { described_class.generate_apple_script(item_type: "task", name: "Task", new_name: "Updated") }

    it "updates the requested property" do
      expect(script).to include(%(set name of foundItem to "Updated"))
    end
  end
end
