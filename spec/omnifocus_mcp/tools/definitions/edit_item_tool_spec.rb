# frozen_string_literal: true

require "omnifocus_mcp/tools/definitions/edit_item_tool"

RSpec.describe OmnifocusMcp::Tools::Definitions::EditItemTool do
  let(:edited) { OmnifocusMcp::Tools::Operations::EditItem::Edited }
  let(:tool) { described_class.new }

  before { described_class.operation_factory = nil }
  after  { described_class.operation_factory = nil }

  def silence_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
  ensure
    $stderr = original
  end

  def stub_operation(result)
    captured = nil
    described_class.operation_factory = lambda do
      lambda do |params|
        captured = params
        result
      end
    end
    -> { captured }
  end

  def ok_edited(id:, name:, changed_properties: nil)
    OmnifocusMcp::Result.ok(edited.new(id: id, name: name, changed_properties: changed_properties))
  end

  describe ".tool_name and .description" do
    it "registers with the expected tool name" do
      expect(described_class.tool_name).to eq("edit_item")
    end

    it "registers with the expected tool description" do
      expect(described_class.description).to eq("Edit a task or project in OmniFocus")
    end
  end

  describe ".input_schema_to_json" do
    subject(:schema) { described_class.input_schema_to_json }

    it "exposes all 18 camelCase property names" do
      expect(schema[:properties].keys).to include(
        :id, :name, :itemType,
        :newName, :newNote, :newDueDate, :newDeferDate, :newPlannedDate,
        :newFlagged, :newEstimatedMinutes, :newStatus, :addTags, :removeTags,
        :replaceTags, :newProjectName, :newSequential, :newFolderName, :newProjectStatus
      )
    end

    it "requires itemType" do
      expect(schema[:required]).to eq(["itemType"])
    end
  end

  describe "#call" do
    # Identifier validation runs before McpEnvelope.safely.
    context "with neither id nor name" do
      subject(:envelope) { tool.call(itemType: "task") }

      before { described_class.operation_factory = -> { ->(_) { raise "should not be called" } } }

      it "marks the envelope as an error" do
        expect(envelope[:isError]).to be true
      end

      it "returns a validation message without invoking the operation" do
        expect(envelope[:content].first[:text]).to eq("Either id or name must be provided to edit an item.")
      end
    end

    context "when id and name are blank strings" do
      subject(:envelope) { tool.call(itemType: "task", id: "", name: "") }

      before { described_class.operation_factory = -> { ->(_) { raise "should not be called" } } }

      it "rejects the request as missing an identifier" do
        expect(envelope[:content].first[:text]).to eq("Either id or name must be provided to edit an item.")
      end
    end

    context "when on success with changed properties" do
      subject(:envelope) { tool.call(name: "Test", itemType: "task", newName: "New") }

      before { stub_operation(ok_edited(id: "T1", name: "Test", changed_properties: "name, due date")) }

      it "renders the changed properties in parentheses" do
        expect(envelope[:content].first[:text])
          .to eq("\u2705 Task \"Test\" updated successfully (name, due date).")
      end

      it "does not mark the envelope as an error" do
        expect(envelope[:isError]).to be_nil
      end
    end

    context "when on success with no changed properties" do
      subject(:envelope) { tool.call(name: "Proj", itemType: "project") }

      before { stub_operation(ok_edited(id: "P1", name: "Proj")) }

      it "omits the parenthesized list" do
        expect(envelope[:content].first[:text]).to eq("\u2705 Project \"Proj\" updated successfully.")
      end
    end

    context "when the operation returns 'Item not found'" do
      before { stub_operation(OmnifocusMcp::Result.error("Item not found")) }

      context "when lookup used id only" do
        subject(:envelope) { tool.call(id: "X", itemType: "task") }

        it "produces a friendly not-found message with the id" do
          expect(envelope[:content].first[:text]).to eq('Task not found with ID "X".')
        end
      end

      context "when lookup used name only" do
        subject(:envelope) { tool.call(name: "Test", itemType: "task") }

        it "produces a friendly not-found message with the name" do
          expect(envelope[:content].first[:text]).to eq('Task not found with name "Test".')
        end
      end

      context "when lookup used both id and name" do
        subject(:envelope) { tool.call(id: "X", name: "Test", itemType: "task") }

        it "produces a friendly not-found message with both identifiers" do
          expect(envelope[:content].first[:text]).to eq('Task not found with ID "X" or name "Test".')
        end
      end
    end

    context "when the operation returns a generic error" do
      subject(:envelope) { tool.call(id: "T1", itemType: "task") }

      before { stub_operation(OmnifocusMcp::Result.error("permission denied")) }

      it "marks the envelope as an error" do
        expect(envelope[:isError]).to be true
      end

      it "includes the operation error in the failure message" do
        expect(envelope[:content].first[:text]).to eq("Failed to update task: permission denied")
      end
    end

    context "when the operation raises" do
      before { described_class.operation_factory = -> { ->(_) { raise "boom" } } }

      context "when for a task" do
        let(:args) { { name: "x", itemType: "task" } }

        it "marks the envelope as an error" do
          envelope = silence_stderr { tool.call(**args) }

          expect(envelope[:isError]).to be true
        end

        it "wraps the message with the task item type" do
          envelope = silence_stderr { tool.call(**args) }

          expect(envelope[:content].first[:text]).to eq("Error updating task: boom")
        end

        it "warns with the exception details on stderr" do
          expect { tool.call(**args) }.to output(/Error updating task: boom/).to_stderr
        end
      end

      context "when for a project" do
        let(:args) { { name: "x", itemType: "project" } }

        it "wraps the message with the project item type" do
          envelope = silence_stderr { tool.call(**args) }

          expect(envelope[:content].first[:text]).to eq("Error updating project: boom")
        end
      end
    end
  end
end
