# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/edit_item"

RSpec.describe OmnifocusMcp::Tools::Generators::EditItem do
  describe ".generate_apple_script" do
    subject(:script) { described_class.generate_apple_script(item_type: "task", name: "Task", new_name: "Updated") }

    it "updates the requested property" do
      expect(script).to include(%(set name of foundItem to "Updated"))
    end

    it "escapes the item name in the reply" do
      expect(script).to include("my jsonEscape(itemName)")
    end

    context "with a multi-line note" do
      subject(:script) do
        described_class.generate_apple_script(item_type: "task", id: "abc", new_note: "Status: open\nBody")
      end

      it "keeps the line break" do
        expect(script).to include('set note of foundItem to "Status: open\nBody"')
      end
    end

    context "with a multi-line name" do
      subject(:script) do
        described_class.generate_apple_script(item_type: "task", id: "abc", new_name: "One\nTwo")
      end

      it "collapses the line break to a space" do
        expect(script).to include('set name of foundItem to "One Two"')
      end
    end
  end
end
