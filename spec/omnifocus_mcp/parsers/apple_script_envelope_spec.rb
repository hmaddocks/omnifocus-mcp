# frozen_string_literal: true

require "omnifocus_mcp/parsers/apple_script_envelope"

RSpec.describe OmnifocusMcp::Parsers::AppleScriptEnvelope do
  subject(:parse) do
    described_class.parse(stdout:, default_error: "Unknown error in widget_op") do |hash|
      OmnifocusMcp::Result.ok(hash.fetch("widgetId"))
    end
  end

  context "when stdout is not valid JSON" do
    let(:stdout) { "not json at all" }

    it "is an error result" do
      expect(parse).to be_error
    end

    it "includes the JSON parser's diagnostic" do
      expect(parse.error).to match(/Failed to parse AppleScript result \(.+?\)/)
    end

    it "includes the stdout preview" do
      expect(parse.error).to include("not json at all")
    end
  end

  context "when stdout is empty" do
    let(:stdout) { "" }

    it "returns an error result" do
      expect(parse).to be_error
    end

    it "includes a parse failure diagnostic" do
      expect(parse.error).to match(/Failed to parse AppleScript result/)
    end
  end

  context "when stdout is far larger than the preview limit" do
    let(:stdout) { "x" * 5_000 }

    it "bounds the total error length so logs are not swamped" do
      expect(parse.error.length).to be < (described_class::STDOUT_PREVIEW_LIMIT * 3)
    end
  end

  describe "public API" do
    it "exposes only .parse, keeping parse_json/from_envelope as internals" do
      expect(described_class.singleton_methods(false)).to contain_exactly(:parse)
    end
  end

  context "when the envelope has success: true" do
    let(:stdout) { '{"success":true,"widgetId":"w-123"}' }

    it "passes the parsed hash to the block and returns the block's Result" do
      expect(parse.ok).to eq("w-123")
    end
  end

  context "when the envelope has success: false with an explicit error" do
    let(:stdout) { '{"success":false,"error":"Widget not found"}' }

    it "returns an error result" do
      expect(parse).to be_error
    end

    it "returns the explicit error message" do
      expect(parse.error).to eq("Widget not found")
    end
  end

  context "when the envelope has success: false with no error field" do
    let(:stdout) { '{"success":false}' }

    it "returns an error result" do
      expect(parse).to be_error
    end

    it "falls back to the supplied default_error" do
      expect(parse.error).to eq("Unknown error in widget_op")
    end
  end

  context "when the envelope has success: false with an empty error string" do
    let(:stdout) { '{"success":false,"error":""}' }

    it "returns an error result" do
      expect(parse).to be_error
    end

    it "preserves the empty error string instead of falling back" do
      expect(parse.error).to eq("")
    end
  end

  context "when the envelope omits the success key" do
    let(:stdout) { '{"widgetId":"w-1"}' }

    it "returns an error result" do
      expect(parse).to be_error
    end

    it "falls back to the supplied default_error" do
      expect(parse.error).to eq("Unknown error in widget_op")
    end
  end

  context "when stdout parses to a JSON array" do
    let(:stdout) { "[1,2]" }

    it "returns an error result" do
      expect(parse).to be_error
    end

    it "falls back to the supplied default_error" do
      expect(parse.error).to eq("Unknown error in widget_op")
    end
  end

  context "when stdout parses to a JSON string" do
    let(:stdout) { '"hello"' }

    it "returns an error result" do
      expect(parse).to be_error
    end

    it "falls back to the supplied default_error" do
      expect(parse.error).to eq("Unknown error in widget_op")
    end
  end

  context "when the block itself returns a Result.error" do
    let(:stdout) { '{"success":true,"widgetId":"w-9"}' }

    it "short-circuits the pipeline with the block's error" do
      result = described_class.parse(stdout:, default_error: "Unknown") do |_hash|
        OmnifocusMcp::Result.error("downstream failure")
      end

      expect(result.error).to eq("downstream failure")
    end
  end
end
