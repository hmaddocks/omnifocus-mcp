# frozen_string_literal: true

require "omnifocus_mcp/tools/messages/add_project"

RSpec.describe OmnifocusMcp::Tools::Messages::AddProject do
  describe ".success" do
    subject(:message) { described_class.success(name: "Launch", folderName: "Work", sequential: true) }

    it "formats the project creation reply" do
      expect(message).to eq('✅ Project "Launch" created successfully in folder "Work" (sequential).')
    end
  end
end
