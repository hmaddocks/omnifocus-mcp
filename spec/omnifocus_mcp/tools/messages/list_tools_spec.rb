# frozen_string_literal: true

require "omnifocus_mcp/tools/messages/list_tools"

RSpec.describe OmnifocusMcp::Tools::Messages::ListTools do
  describe ".list_tags_failure" do
    subject(:message) { described_class.list_tags_failure("boom") }

    it "formats list tag failures" do
      expect(message).to eq("Failed to list tags: boom")
    end
  end

  describe ".perspective_view_failure" do
    subject(:message) { described_class.perspective_view_failure("boom") }

    it "formats perspective view failures" do
      expect(message).to eq("Failed to get perspective view: boom")
    end
  end
end
