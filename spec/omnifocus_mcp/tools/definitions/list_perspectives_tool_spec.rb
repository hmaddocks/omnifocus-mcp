# frozen_string_literal: true

require "omnifocus_mcp/tools/definitions/list_perspectives_tool"

RSpec.describe OmnifocusMcp::Tools::Definitions::ListPerspectivesTool do
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
      expect(described_class.tool_name).to eq("list_perspectives")
    end

    it "registers with the expected tool description" do
      expect(described_class.description).to include("List all available perspectives in OmniFocus")
    end
  end

  describe ".input_schema_to_json" do
    subject(:schema) { described_class.input_schema_to_json }

    it "exposes includeBuiltIn and includeCustom as optional properties" do
      expect(schema[:properties].keys).to include(:includeBuiltIn, :includeCustom)
    end

    it "does not require any arguments" do
      expect(schema[:required]).to eq([])
    end
  end

  describe "#call" do
    context "with built-in and custom perspectives" do
      subject(:envelope) { tool.call }

      before do
        stub_operation(
          OmnifocusMcp::Result.ok([
                                    { "name" => "Inbox",  "type" => "builtin" },
                                    { "name" => "Tags",   "type" => "builtin" },
                                    { "name" => "Triage", "type" => "custom" }
                                  ])
        )
      end

      let(:text) { envelope[:content].first[:text] }

      it "renders a header with the total count" do
        expect(text).to start_with("## Available Perspectives (3)")
      end

      it "renders built-in and custom sections" do
        expect(text).to include(
          "### Built-in Perspectives\n\u2022 Inbox\n\u2022 Tags",
          "### Custom Perspectives\n\u2022 Triage"
        )
      end

      it "does not mark the envelope as an error" do
        expect(envelope[:isError]).to be_nil
      end
    end

    context "with only built-in perspectives" do
      subject(:envelope) { tool.call }

      before do
        stub_operation(
          OmnifocusMcp::Result.ok([{ "name" => "Inbox", "type" => "builtin" }])
        )
      end

      let(:text) { envelope[:content].first[:text] }

      it "renders the built-in section" do
        expect(text).to include("### Built-in Perspectives\n\u2022 Inbox")
      end

      it "omits the custom section" do
        expect(text).not_to include("### Custom Perspectives")
      end
    end

    context "with only custom perspectives" do
      subject(:envelope) { tool.call }

      before do
        stub_operation(
          OmnifocusMcp::Result.ok([{ "name" => "Triage", "type" => "custom" }])
        )
      end

      let(:text) { envelope[:content].first[:text] }

      it "renders the custom section" do
        expect(text).to include("### Custom Perspectives\n\u2022 Triage")
      end

      it "omits the built-in section" do
        expect(text).not_to include("### Built-in Perspectives")
      end
    end

    context "with an unrecognized perspective type" do
      subject(:envelope) { tool.call }

      before do
        stub_operation(
          OmnifocusMcp::Result.ok([{ "name" => "Mystery", "type" => "other" }])
        )
      end

      let(:text) { envelope[:content].first[:text] }

      it "counts the item in the header" do
        expect(text).to start_with("## Available Perspectives (1)")
      end

      it "omits both section headers" do
        expect(text).not_to include("### Built-in Perspectives", "### Custom Perspectives")
      end
    end

    context "when no perspectives are returned" do
      subject(:envelope) { tool.call }

      before { stub_operation(OmnifocusMcp::Result.ok([])) }

      it "falls back to a 'No perspectives found.' message" do
        expect(envelope[:content].first[:text]).to eq("No perspectives found.")
      end
    end

    context "when passing filter flags to the operation" do
      subject(:params) { get_captured.call }

      let(:get_captured) { stub_operation(OmnifocusMcp::Result.ok([])) }

      before do
        get_captured
        tool.call(includeBuiltIn: false, includeCustom: true)
      end

      it "forwards include_built_in and include_custom to the operation" do
        expect(params).to have_attributes(include_built_in: false, include_custom: true)
      end
    end

    context "when no filter flags are provided" do
      subject(:params) { get_captured.call }

      before do
        get_captured
        tool.call
      end

      let(:get_captured) { stub_operation(OmnifocusMcp::Result.ok([])) }

      it "defaults includeBuiltIn and includeCustom to true" do
        expect(params).to have_attributes(include_built_in: true, include_custom: true)
      end
    end

    context "when the operation fails" do
      subject(:envelope) { tool.call }

      before { stub_operation(OmnifocusMcp::Result.error("broken")) }

      it "marks the envelope as an error" do
        expect(envelope[:isError]).to be true
      end

      it "includes the operation error message" do
        expect(envelope[:content].first[:text]).to eq("Failed to list perspectives: broken")
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

        expect(envelope[:content].first[:text]).to eq("Error listing perspectives: boom")
      end

      it "warns with the exception details on stderr" do
        expect { tool.call }.to output(/Error listing perspectives: boom/).to_stderr
      end
    end
  end
end
