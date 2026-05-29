# frozen_string_literal: true

require "omnifocus_mcp/tools/definitions/batch_add_items_tool"

RSpec.describe OmnifocusMcp::Tools::Definitions::BatchAddItemsTool do
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

  def ok_per_item(id)
    OmnifocusMcp::Result.ok(id)
  end

  def err_per_item(message)
    OmnifocusMcp::Result.error(message)
  end

  describe ".tool_name and .description" do
    it "registers with the expected tool metadata" do
      expect(described_class.tool_name).to eq("batch_add_items")
      expect(described_class.description)
        .to eq("Add multiple tasks or projects to OmniFocus in a single operation")
    end
  end

  describe ".input_schema_to_json" do
    subject(:schema) { described_class.input_schema_to_json }

    it "requires items" do
      expect(schema[:required]).to eq(["items"])
    end

    # createSequentially is exposed to MCP clients but not yet forwarded to the operation.
    it "exposes createSequentially alongside the items array" do
      expect(schema[:properties].keys).to include(:items, :createSequentially)
    end
  end

  describe "#call" do
    context "with two successful adds" do
      subject(:envelope) do
        tool.call(
          items: [
            { type: "project", name: "Launch" },
            { type: "task",    name: "Sub" }
          ]
        )
      end

      before do
        stub_operation(OmnifocusMcp::Result.ok([ok_per_item("P1"), ok_per_item("T1")]))
      end

      let(:text) { envelope[:content].first[:text] }

      it "opens with a success tally" do
        expect(text).to start_with("\u2705 Successfully added 2 items.")
      end

      it "lists each successful item" do
        expect(text).to include("- \u2705 project: \"Launch\"")
        expect(text).to include("- \u2705 task: \"Sub\"")
      end

      it "does not mark the envelope as an error" do
        expect(envelope[:isError]).to be_nil
      end
    end

    context "with partial failures" do
      subject(:envelope) do
        tool.call(
          items: [
            { type: "project", name: "Launch" },
            { type: "task",    name: "Bad", parentTempId: "ghost" }
          ]
        )
      end

      before do
        stub_operation(OmnifocusMcp::Result.ok([ok_per_item("P1"), err_per_item("Cycle detected")]))
      end

      let(:text) { envelope[:content].first[:text] }

      it "renders a partial-failure tally" do
        expect(text).to start_with("\u2705 Successfully added 1 items. \u26A0\uFE0F Failed to add 1 items.")
      end

      it "includes the failed item detail line" do
        expect(text).to include("- \u274C task: \"Bad\" - Error: Cycle detected")
      end
    end

    context "when every item fails at the per-item level" do
      subject(:envelope) do
        tool.call(
          items: [
            { type: "task", name: "A" },
            { type: "task", name: "B" }
          ]
        )
      end

      before do
        stub_operation(OmnifocusMcp::Result.ok([err_per_item("nope"), err_per_item("also nope")]))
      end

      let(:text) { envelope[:content].first[:text] }

      it "reports zero successes and all failures in the tally" do
        expect(text).to start_with("\u2705 Successfully added 0 items. \u26A0\uFE0F Failed to add 2 items.")
      end

      it "marks the envelope as an error when every item failed" do
        expect(envelope[:isError]).to be true
      end

      it "lists each failed item" do
        expect(text).to include("- \u274C task: \"A\" - Error: nope")
        expect(text).to include("- \u274C task: \"B\" - Error: also nope")
      end
    end

    context "when the batch operation fails outright" do
      before { stub_operation(OmnifocusMcp::Result.error("catastrophe")) }

      let(:items) { [{ type: "task", name: "x" }] }

      it "marks the envelope as an error" do
        envelope = silence_stderr { tool.call(items:) }

        expect(envelope[:isError]).to be true
      end

      it "returns real newlines in the error message" do
        envelope = silence_stderr { tool.call(items:) }

        expect(envelope[:content].first[:text])
          .to eq("Failed to process batch operation.\n\nNo items processed. catastrophe")
      end

      it "warns about the batch failure on stderr" do
        expect { tool.call(items:) }.to output(/\[batch_add_items\] failure result:/).to_stderr
      end
    end

    context "when the operation raises" do
      before { described_class.operation_factory = -> { ->(_) { raise "boom" } } }

      let(:items) { [{ type: "task", name: "x" }] }

      it "marks the envelope as an error" do
        envelope = silence_stderr { tool.call(items:) }

        expect(envelope[:isError]).to be true
      end

      it "includes the safely-wrapped exception message" do
        envelope = silence_stderr { tool.call(items:) }

        expect(envelope[:content].first[:text]).to eq("Error processing batch operation: boom")
      end

      it "warns with the exception details on stderr" do
        expect { tool.call(items:) }.to output(/Error processing batch operation: boom/).to_stderr
      end
    end

    context "when items arrive with String keys (fast-mcp's nested-Array delivery)" do
      it "renders the per-item detail line using the item's name and type" do
        stub_operation(OmnifocusMcp::Result.ok([ok_per_item("T1")]))

        envelope = tool.call(items: [{ "type" => "task", "name" => "X" }])

        expect(envelope[:content].first[:text]).to include("- \u2705 task: \"X\"")
      end
    end
  end
end
