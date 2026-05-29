# frozen_string_literal: true

require "omnifocus_mcp/tools/definitions/get_perspective_view_tool"

RSpec.describe OmnifocusMcp::Tools::Definitions::GetPerspectiveViewTool do
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

  describe ".tool_name and .description" do
    it "registers with the expected tool name" do
      expect(described_class.tool_name).to eq("get_perspective_view")
    end

    it "registers with the expected tool description" do
      expect(described_class.description).to start_with("Get the items visible in a specific OmniFocus perspective")
    end
  end

  describe ".input_schema_to_json" do
    subject(:schema) { described_class.input_schema_to_json }

    it "requires perspectiveName" do
      expect(schema[:required]).to eq(["perspectiveName"])
    end

    it "exposes limit and fields as optional properties" do
      expect(schema[:properties].keys).to include(:perspectiveName, :limit, :fields)
    end
  end

  describe "#call" do
    context "when the perspective has items" do
      subject(:envelope) { tool.call(perspectiveName: "Flagged") }

      let(:text) { envelope[:content].first[:text] }
      let(:items) do
        [
          {
            "id" => "T1", "name" => "Reply", "completed" => false, "flagged" => true,
            "projectName" => "Inbox Zero", "dueDate" => "2026-05-23",
            "estimatedMinutes" => 30, "tagNames" => ["urgent"], "taskStatus" => "Next"
          }
        ]
      end

      before { stub_operation(OmnifocusMcp::Result.ok(items)) }

      it "renders a header with the perspective name and item count" do
        expect(text).to start_with("## Flagged Perspective (1 items)")
      end

      it "formats each item on its own line" do
        expect(text).to include("\u2022 \u2610 \u{1F6A9} Reply (Inbox Zero) [due: 5/23] (30m) <urgent> #next [T1]")
      end

      it "does not mark the envelope as an error" do
        expect(envelope[:isError]).to be_nil
      end
    end

    context "when an item is completed" do
      subject(:envelope) { tool.call(perspectiveName: "Completed") }

      before do
        stub_operation(
          OmnifocusMcp::Result.ok([{ "id" => "T1", "name" => "Done", "completed" => true }])
        )
      end

      it "uses the checked checkbox" do
        expect(envelope[:content].first[:text]).to include("\u2022 \u2611 Done")
      end
    end

    context "when an item has a long estimated duration" do
      subject(:envelope) { tool.call(perspectiveName: "P") }

      before do
        stub_operation(
          OmnifocusMcp::Result.ok([{ "id" => "T1", "name" => "Deep work", "estimatedMinutes" => 90 }])
        )
      end

      it "renders hours and remaining minutes" do
        expect(envelope[:content].first[:text]).to include("(1h30m)")
      end
    end

    context "when an item has Available task status" do
      subject(:envelope) { tool.call(perspectiveName: "P") }

      before do
        stub_operation(
          OmnifocusMcp::Result.ok([
                                    { "id" => "T1", "name" => "Ready", "taskStatus" => "Available" }
                                  ])
        )
      end

      it "omits the status hashtag" do
        expect(envelope[:content].first[:text]).not_to include("#available")
      end
    end

    context "when an item has a defer date" do
      subject(:envelope) { tool.call(perspectiveName: "P") }

      before do
        stub_operation(
          OmnifocusMcp::Result.ok([
                                    { "id" => "T1", "name" => "Later", "deferDate" => "2026-05-22" }
                                  ])
        )
      end

      it "renders the defer date in compact format" do
        expect(envelope[:content].first[:text]).to include("[defer: 5/22]")
      end
    end

    context "when an item has a note" do
      subject(:envelope) { tool.call(perspectiveName: "P") }

      before do
        stub_operation(
          OmnifocusMcp::Result.ok([
                                    { "id" => "T1", "name" => "Reply", "note" => "Follow up tomorrow" }
                                  ])
        )
      end

      it "appends an indented note preview" do
        expect(envelope[:content].first[:text]).to include("  \u2514\u2500 Follow up tomorrow")
      end
    end

    context "when the perspective is empty" do
      subject(:envelope) { tool.call(perspectiveName: "Custom") }

      before { stub_operation(OmnifocusMcp::Result.ok([])) }

      it "shows the empty-perspective message" do
        expect(envelope[:content].first[:text]).to include("No items visible in this perspective.")
      end
    end

    context "when the result count equals the limit" do
      subject(:envelope) { tool.call(perspectiveName: "P", limit: 2) }

      before do
        stub_operation(
          OmnifocusMcp::Result.ok(Array.new(2) { |i| { "id" => "T#{i}", "name" => "n#{i}" } })
        )
      end

      it "appends the limit warning" do
        expect(envelope[:content].first[:text])
          .to include("\u26A0\uFE0F Results limited to 2 items.")
      end
    end

    context "when the result count is below the limit" do
      subject(:envelope) { tool.call(perspectiveName: "P", limit: 2) }

      before do
        stub_operation(
          OmnifocusMcp::Result.ok([{ "id" => "T1", "name" => "Only one" }])
        )
      end

      it "does not append the limit warning" do
        expect(envelope[:content].first[:text]).not_to include("\u26A0\uFE0F Results limited")
      end
    end

    context "when passing args to the operation" do
      subject(:params) { get_captured.call }

      before do
        get_captured
        tool.call(perspectiveName: "P", limit: 25, fields: ["name"])
      end

      let(:get_captured) { stub_operation(OmnifocusMcp::Result.ok([])) }

      it "forwards perspective_name, limit, and fields to the operation" do
        expect(params).to have_attributes(perspective_name: "P", limit: 25, fields: ["name"])
      end
    end

    context "when no limit is provided" do
      subject(:params) { get_captured.call }

      before do
        get_captured
        tool.call(perspectiveName: "P")
      end

      let(:get_captured) { stub_operation(OmnifocusMcp::Result.ok([])) }

      it "defaults the limit to 100" do
        expect(params.limit).to eq(100)
      end
    end

    context "when the operation fails" do
      subject(:envelope) { tool.call(perspectiveName: "P") }

      before { stub_operation(OmnifocusMcp::Result.error("kaboom")) }

      it "marks the envelope as an error" do
        expect(envelope[:isError]).to be true
      end

      it "includes the operation error message" do
        expect(envelope[:content].first[:text]).to eq("Failed to get perspective view: kaboom")
      end
    end

    context "when the operation raises" do
      before { described_class.operation_factory = -> { ->(_) { raise "boom" } } }

      let(:args) { { perspectiveName: "P" } }

      it "marks the envelope as an error" do
        envelope = silence_stderr { tool.call(**args) }

        expect(envelope[:isError]).to be true
      end

      it "includes the safely-wrapped exception message" do
        envelope = silence_stderr { tool.call(**args) }

        expect(envelope[:content].first[:text]).to eq("Error getting perspective view: boom")
      end

      it "warns with the exception details on stderr" do
        expect { tool.call(**args) }.to output(/Error getting perspective view: boom/).to_stderr
      end
    end
  end
end
