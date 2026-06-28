# frozen_string_literal: true

require "omnifocus_mcp/tools/messages/remove_item"

RSpec.describe OmnifocusMcp::Tools::Messages::RemoveItem do
  describe ".success" do
    subject(:message) { described_class.success({ itemType: "task" }, removed) }

    let(:removed) { Struct.new(:name).new("Old task") }

    it "formats the removal reply" do
      expect(message).to eq('✅ Task "Old task" removed successfully.')
    end
  end

  describe ".failure" do
    subject(:message) { described_class.failure({ itemType: "task", id: "abc" }, "Item not found") }

    it "formats item-not-found errors with lookup context" do
      expect(message).to eq('Task not found with ID "abc".')
    end
  end
end
