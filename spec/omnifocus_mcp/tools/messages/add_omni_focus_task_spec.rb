# frozen_string_literal: true

require "omnifocus_mcp/tools/messages/add_omni_focus_task"

RSpec.describe OmnifocusMcp::Tools::Messages::AddOmniFocusTask do
  describe ".success" do
    subject(:message) { described_class.success(args, result) }

    let(:args) { { name: "Buy milk", tags: ["Errands"], parentTaskId: "ghost" } }
    let(:result) { Struct.new(:placement).new("inbox") }

    it "formats the task creation reply with placement warning" do
      expect(message).to include("Parent not found; task created in inbox.")
    end
  end
end
