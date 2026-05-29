# frozen_string_literal: true

require "omnifocus_mcp/tools/messages/add_omnifocus_task"
require "omnifocus_mcp/tools/messages/add_project"
require "omnifocus_mcp/tools/messages/batch_remove_items"
require "omnifocus_mcp/tools/messages/edit_item"
require "omnifocus_mcp/tools/messages/list_tools"
require "omnifocus_mcp/tools/messages/remove_item"

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

RSpec.describe OmnifocusMcp::Tools::Messages::AddProject do
  describe ".success" do
    subject(:message) { described_class.success(name: "Launch", folderName: "Work", sequential: true) }

    it "formats the project creation reply" do
      expect(message).to eq('✅ Project "Launch" created successfully in folder "Work" (sequential).')
    end
  end
end

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

RSpec.describe OmnifocusMcp::Tools::Messages::BatchRemoveItems do
  describe ".missing_identifier" do
    subject(:message) { described_class.missing_identifier }

    it "formats missing identifier validation" do
      expect(message).to eq("Each item must have either id or name provided to remove it.")
    end
  end
end
