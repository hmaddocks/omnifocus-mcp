# frozen_string_literal: true

require "omnifocus_mcp/tools/messages/batch_remove_items"

RSpec.describe OmnifocusMcp::Tools::Messages::BatchRemoveItems do
  describe ".missing_identifier" do
    subject(:message) { described_class.missing_identifier }

    it "formats missing identifier validation" do
      expect(message).to eq("Each item must have either id or name provided to remove it.")
    end
  end
end
