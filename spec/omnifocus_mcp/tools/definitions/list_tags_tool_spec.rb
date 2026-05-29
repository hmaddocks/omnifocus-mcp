# frozen_string_literal: true

require "omnifocus_mcp/tools/definitions/list_tags_tool"

RSpec.describe OmnifocusMcp::Tools::Definitions::ListTagsTool do
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
      expect(described_class.tool_name).to eq("list_tags")
    end

    it "registers with the expected tool description" do
      expect(described_class.description).to include("List all tags in OmniFocus with their hierarchy")
    end
  end

  describe ".input_schema_to_json" do
    subject(:schema) { described_class.input_schema_to_json }

    it "exposes includeDropped as an optional property" do
      expect(schema[:properties].keys).to include(:includeDropped)
    end

    it "does not require any arguments" do
      expect(schema[:required]).to eq([])
    end
  end

  describe "#call" do
    context "with nested tags" do
      subject(:envelope) { tool.call }

      let(:text) { envelope[:content].first[:text] }
      let(:tags) do
        [
          { "id" => "1", "name" => "Work",   "active" => true,  "taskCount" => 5,
            "parentTagID" => nil },
          { "id" => "2", "name" => "Email",  "active" => true,  "taskCount" => 0,
            "parentTagID" => "1" },
          { "id" => "3", "name" => "Office", "active" => false, "taskCount" => 0,
            "parentTagID" => "1" }
        ]
      end

      before { stub_operation(OmnifocusMcp::Result.ok(tags)) }

      it "renders a header with the total count" do
        expect(text).to start_with("## Tags (3)")
      end

      it "renders top-level tags with nested children indented" do
        expect(text).to include(
          "- **Work** [5 tasks] (id: 1)",
          "  - **Email** (id: 2)",
          "  - **Office** (inactive) (id: 3)"
        )
      end

      it "does not mark the envelope as an error" do
        expect(envelope[:isError]).to be_nil
      end
    end

    context "with orphan nested tags whose parent is missing from the result set" do
      subject(:envelope) { tool.call }

      let(:text) { envelope[:content].first[:text] }

      before do
        stub_operation(
          OmnifocusMcp::Result.ok([
                                    { "id" => "2", "name" => "Email", "active" => true, "taskCount" => 0,
                                      "parentTagID" => "missing-parent" }
                                  ])
        )
      end

      it "renders the orphan at the top level" do
        expect(text).to include("- **Email** (id: 2)")
      end

      it "does not indent the orphan" do
        expect(text).not_to include("  - **Email**")
      end
    end

    context "when no tags are returned" do
      subject(:envelope) { tool.call }

      before { stub_operation(OmnifocusMcp::Result.ok([])) }

      it "renders 'No tags found.'" do
        expect(envelope[:content].first[:text]).to eq("No tags found.")
      end
    end

    context "when passing includeDropped to the operation" do
      subject(:params) { get_captured.call }

      before do
        get_captured
        tool.call(includeDropped: true)
      end

      let(:get_captured) { stub_operation(OmnifocusMcp::Result.ok([])) }

      it "forwards include_dropped to the operation" do
        expect(params).to have_attributes(include_dropped: true)
      end
    end

    context "when includeDropped is omitted" do
      subject(:params) { get_captured.call }

      before do
        get_captured
        tool.call
      end

      let(:get_captured) { stub_operation(OmnifocusMcp::Result.ok([])) }

      it "defaults include_dropped to false" do
        expect(params).to have_attributes(include_dropped: false)
      end
    end

    context "when the operation fails" do
      subject(:envelope) { tool.call }

      before { stub_operation(OmnifocusMcp::Result.error("kaboom")) }

      it "marks the envelope as an error" do
        expect(envelope[:isError]).to be true
      end

      it "includes the operation error message" do
        expect(envelope[:content].first[:text]).to eq("Failed to list tags: kaboom")
      end
    end

    context "when the operation raises" do
      before { described_class.operation_factory = -> { ->(_) { raise "boom" } } }

      it "marks the envelope as an error" do
        envelope = silence_stderr { tool.call }

        expect(envelope[:isError]).to be true
      end

      it "includes the safely-wrapped exception message" do
        envelope = silence_stderr { tool.call }

        expect(envelope[:content].first[:text]).to eq("Error listing tags: boom")
      end

      it "warns with the exception details on stderr" do
        expect { tool.call }.to output(/Error listing tags: boom/).to_stderr
      end
    end
  end
end
