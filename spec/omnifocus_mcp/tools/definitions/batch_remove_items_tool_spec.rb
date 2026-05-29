# frozen_string_literal: true

require "omnifocus_mcp/tools/definitions/batch_remove_items_tool"

RSpec.describe OmnifocusMcp::Tools::Definitions::BatchRemoveItemsTool do
  let(:removed) { OmnifocusMcp::Tools::Operations::RemoveItem::Removed }
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
      lambda do |items|
        captured = items
        result
      end
    end
    -> { captured }
  end

  def ok_removed(name:, id: nil)
    OmnifocusMcp::Result.ok(removed.new(id: id, name: name))
  end

  describe ".tool_name and .description" do
    it "registers with the expected tool name" do
      expect(described_class.tool_name).to eq("batch_remove_items")
    end

    it "registers with the expected tool description" do
      expect(described_class.description)
        .to eq("Remove multiple tasks or projects from OmniFocus in a single operation")
    end
  end

  describe ".input_schema_to_json" do
    subject(:schema) { described_class.input_schema_to_json }

    it "requires items" do
      expect(schema[:required]).to eq(["items"])
    end

    it "requires itemType on each item" do
      item_schema = schema.dig(:properties, :items, :items)
      expect(item_schema[:required]).to include("itemType")
    end
  end

  describe "#call" do
    # Validation runs before McpEnvelope.safely, so missing identifiers never reach the operation.
    context "when an item has neither id nor name" do
      subject(:envelope) { tool.call(items: [{ itemType: "task" }]) }

      before { described_class.operation_factory = -> { ->(_) { raise "should not be called" } } }

      it "marks the envelope as an error" do
        expect(envelope[:isError]).to be true
      end

      it "returns a validation message without calling the operation" do
        expect(envelope[:content].first[:text])
          .to eq("Each item must have either id or name provided to remove it.")
      end
    end

    context "when an item has blank id and name strings" do
      subject(:envelope) { tool.call(items: [{ itemType: "task", id: "", name: "" }]) }

      before { described_class.operation_factory = -> { ->(_) { raise "should not be called" } } }

      it "rejects the item as missing an identifier" do
        expect(envelope[:content].first[:text])
          .to eq("Each item must have either id or name provided to remove it.")
      end
    end

    context "with two successful removals" do
      subject(:envelope) do
        tool.call(
          items: [
            { itemType: "task",    name: "A" },
            { itemType: "project", name: "B" }
          ]
        )
      end

      before do
        stub_operation(
          OmnifocusMcp::Result.ok([
                                    ok_removed(name: "A"),
                                    ok_removed(name: "B")
                                  ])
        )
      end

      let(:text) { envelope[:content].first[:text] }

      it "opens with a success tally" do
        expect(text).to start_with("\u2705 Successfully removed 2 items.")
      end

      it "lists each successful item by type" do
        expect(text).to include("- \u2705 task: \"A")
      end

      it "lists each successful item by removed name" do
        expect(text).to include("- \u2705 project: \"B")
      end

      it "does not mark the envelope as an error" do
        expect(envelope[:isError]).to be_nil
      end
    end

    context "when removing by id only" do
      subject(:envelope) { tool.call(items: [{ itemType: "task", id: "T1" }]) }

      before do
        stub_operation(OmnifocusMcp::Result.ok([ok_removed(name: "Resolved", id: "T1")]))
      end

      it "shows the resolved name from the operation result" do
        expect(envelope[:content].first[:text]).to include("- \u2705 task: \"Resolved\"")
      end
    end

    context "with mixed successes and failures" do
      subject(:envelope) do
        tool.call(
          items: [
            { itemType: "task", name: "A" },
            { itemType: "task", id: "X-id" }
          ]
        )
      end

      before do
        stub_operation(
          OmnifocusMcp::Result.ok([
                                    ok_removed(name: "A"),
                                    OmnifocusMcp::Result.error("missing")
                                  ])
        )
      end

      let(:text) { envelope[:content].first[:text] }

      it "renders a partial-failure tally" do
        expect(text).to start_with("\u2705 Successfully removed 1 items. \u26A0\uFE0F Failed to remove 1 items.")
      end

      it "identifies failed items by id when name is absent" do
        expect(text).to include("- \u274C task: X-id - Error: missing")
      end
    end

    context "when every item fails at the per-item level" do
      subject(:envelope) do
        tool.call(
          items: [
            { itemType: "task", name: "A" },
            { itemType: "task", name: "B" }
          ]
        )
      end

      before do
        stub_operation(
          OmnifocusMcp::Result.ok([
                                    OmnifocusMcp::Result.error("gone"),
                                    OmnifocusMcp::Result.error("also gone")
                                  ])
        )
      end

      let(:text) { envelope[:content].first[:text] }

      it "reports zero successes and all failures in the tally" do
        expect(text).to start_with("\u2705 Successfully removed 0 items. \u26A0\uFE0F Failed to remove 2 items.")
      end

      it "marks the envelope as an error when every item failed" do
        expect(envelope[:isError]).to be true
      end
    end

    context "when the batch operation fails outright" do
      subject(:envelope) { tool.call(items: [{ itemType: "task", name: "A" }]) }

      before { stub_operation(OmnifocusMcp::Result.error("no OmniFocus")) }

      it "marks the envelope as an error" do
        expect(envelope[:isError]).to be true
      end

      it "includes the top-level error message" do
        expect(envelope[:content].first[:text])
          .to eq("Failed to process batch operation.\n\nNo items processed. no OmniFocus")
      end
    end

    context "when the operation raises" do
      before { described_class.operation_factory = -> { ->(_) { raise "boom" } } }

      let(:items) { [{ itemType: "task", name: "A" }] }

      it "marks the envelope as an error" do
        envelope = silence_stderr { tool.call(items:) }

        expect(envelope[:isError]).to be true
      end

      it "includes the safely-wrapped exception message" do
        envelope = silence_stderr { tool.call(items:) }

        expect(envelope[:content].first[:text]).to eq("Error processing batch removal: boom")
      end

      it "warns with the exception details on stderr" do
        expect { tool.call(items:) }.to output(/Error processing batch removal: boom/).to_stderr
      end
    end

    context "when items arrive with String keys (fast-mcp's nested-Array delivery)" do
      context "with a missing id and name" do
        subject(:envelope) { tool.call(items: [{ "itemType" => "task" }]) }

        before { described_class.operation_factory = -> { ->(_) { raise "should not be called" } } }

        it "still validates against missing id/name correctly" do
          expect(envelope[:content].first[:text])
            .to eq("Each item must have either id or name provided to remove it.")
        end
      end

      context "with valid String-keyed items" do
        it "renders the per-item detail line with the item type" do
          stub_operation(OmnifocusMcp::Result.ok([ok_removed(name: "A")]))

          envelope = tool.call(items: [{ "itemType" => "task", "name" => "A" }])

          expect(envelope[:content].first[:text]).to include("- \u2705 task: \"A\"")
        end
      end
    end
  end
end
