# frozen_string_literal: true

require "omnifocus_mcp/tools/messages/edit_item"

RSpec.describe OmnifocusMcp::Tools::Messages::EditItem do
  describe ".success" do
    subject(:message) { described_class.success({ itemType: "project" }, edited) }

    let(:edited) { Struct.new(:name, :changed_properties).new("Launch", "status") }

    it "formats the edit reply with changed properties" do
      expect(message).to eq('✅ Project "Launch" updated successfully (status).')
    end
  end

  describe ".failure" do
    subject(:message) { described_class.failure({ itemType: "project", name: "Launch" }, "Item not found") }

    it "formats item-not-found errors with lookup context" do
      expect(message).to eq('Project not found with name "Launch".')
    end
  end
end
