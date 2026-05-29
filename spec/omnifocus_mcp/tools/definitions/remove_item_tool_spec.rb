# frozen_string_literal: true

require "omnifocus_mcp/tools/definitions/remove_item_tool"

RSpec.describe OmnifocusMcp::Tools::Definitions::RemoveItemTool do
  let(:removed) { OmnifocusMcp::Tools::Operations::RemoveItem::Removed }
  let(:tool) { described_class.new }

  before { described_class.operation_factory = nil }
  after  { described_class.operation_factory = nil }

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

  def ok_removed(id:, name:)
    OmnifocusMcp::Result.ok(removed.new(id: id, name: name))
  end

  describe ".tool_name and .description" do
    it "registers with the expected tool name" do
      expect(described_class.tool_name).to eq("remove_item")
    end

    it "registers with the expected tool description" do
      expect(described_class.description).to eq("Remove a task or project from OmniFocus")
    end
  end

  describe ".input_schema_to_json" do
    subject(:schema) { described_class.input_schema_to_json }

    it "requires itemType" do
      expect(schema[:required]).to eq(["itemType"])
    end

    it "exposes id and name as optional properties" do
      expect(schema[:properties].keys).to include(:id, :name, :itemType)
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
        expect(envelope[:content].first[:text])
          .to eq("Either id or name must be provided to remove an item.")
      end
    end

    context "when successful removal of a task" do
      subject(:envelope) { tool.call(name: "Old Task", itemType: "task") }

      before { stub_operation(ok_removed(id: "T1", name: "Old Task")) }

      it "renders a Task confirmation" do
        expect(envelope[:content].first[:text]).to eq("\u2705 Task \"Old Task\" removed successfully.")
      end

      it "does not mark the envelope as an error" do
        expect(envelope[:isError]).to be_nil
      end
    end

    context "when successful removal of a project" do
      subject(:envelope) { tool.call(name: "Old Proj", itemType: "project") }

      before { stub_operation(ok_removed(id: "P1", name: "Old Proj")) }

      it "renders a Project confirmation" do
        expect(envelope[:content].first[:text]).to eq("\u2705 Project \"Old Proj\" removed successfully.")
      end
    end

    context "when the operation returns 'Item not found'" do
      before { stub_operation(OmnifocusMcp::Result.error("Item not found")) }

      context "when lookup used both id and name" do
        subject(:envelope) { tool.call(id: "X", name: "Y", itemType: "task") }

        it "produces a friendly not-found message naming both" do
          expect(envelope[:content].first[:text])
            .to eq('Task not found with ID "X" or name "Y".')
        end
      end

      context "when lookup used id only" do
        subject(:envelope) { tool.call(id: "X", itemType: "task") }

        it "produces a friendly not-found message with the id" do
          expect(envelope[:content].first[:text]).to eq('Task not found with ID "X".')
        end
      end

      context "when lookup used name only" do
        subject(:envelope) { tool.call(name: "Y", itemType: "task") }

        it "produces a friendly not-found message with the name" do
          expect(envelope[:content].first[:text]).to eq('Task not found with name "Y".')
        end
      end
    end

    context "when the operation returns a non-not-found error" do
      subject(:envelope) { tool.call(id: "X", itemType: "task") }

      before { stub_operation(OmnifocusMcp::Result.error("kaboom")) }

      it "marks the envelope as an error" do
        expect(envelope[:isError]).to be true
      end

      it "passes the error through" do
        expect(envelope[:content].first[:text]).to eq("Failed to remove task: kaboom")
      end
    end

    context "when the operation raises" do
      subject(:envelope) { tool.call(name: "x", itemType: "task") }

      before { described_class.operation_factory = -> { ->(_) { raise "boom" } } }

      it "wraps the message" do
        expect(envelope[:content].first[:text]).to eq("Error removing task: boom")
      end
    end
  end
end
