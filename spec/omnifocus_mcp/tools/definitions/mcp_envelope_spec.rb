# frozen_string_literal: true

require "omnifocus_mcp/tools/definitions/mcp_envelope"

RSpec.describe OmnifocusMcp::Tools::Definitions::McpEnvelope do
  def silence_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
  ensure
    $stderr = original
  end

  describe ".text_result" do
    subject(:result) { described_class.text_result("hi") }

    it "wraps a string in an MCP success envelope" do
      expect(result).to eq(content: [{ type: "text", text: "hi" }])
    end
  end

  describe ".text_error" do
    subject(:result) { described_class.text_error("oh no") }

    it "wraps a string in an MCP error envelope with isError: true" do
      expect(result).to eq(
        content: [{ type: "text", text: "oh no" }],
        isError: true
      )
    end
  end

  describe "ToolReply" do
    it "converts a success reply to an MCP envelope" do
      envelope = described_class::ToolReply.success("ok").to_envelope

      expect(envelope).to eq(content: [{ type: "text", text: "ok" }])
    end

    it "converts a failure reply to an MCP error envelope" do
      envelope = described_class::ToolReply.failure("nope").to_envelope

      expect(envelope).to eq(
        content: [{ type: "text", text: "nope" }],
        isError: true
      )
    end
  end

  describe ".safely" do
    context "when the block returns a ToolReply" do
      subject(:result) do
        described_class.safely("executing query") do
          described_class::ToolReply.success("done")
        end
      end

      it "converts the reply to an MCP envelope" do
        expect(result).to eq(content: [{ type: "text", text: "done" }])
      end
    end

    context "when the block runs cleanly" do
      subject(:result) { described_class.safely("doing stuff") { envelope } }

      let(:envelope) { { content: [{ type: "text", text: "ok" }] } }

      it "returns the block's value verbatim" do
        expect(result).to eq(envelope)
      end

      it "does not warn on success" do
        expect { described_class.safely("doing stuff") { :ok } }.not_to output.to_stderr
      end
    end

    context "when the block raises a StandardError" do
      subject(:result) { silence_stderr { described_class.safely(scope) { raise "boom" } } }

      let(:scope) { "creating task" }

      it "returns a text_error envelope whose default message follows \"Error <scope>: <e.message>\"" do
        expect(result).to eq(
          content: [{ type: "text", text: "Error creating task: boom" }],
          isError: true
        )
      end

      it "emits the same default message to stderr (warn)" do
        expect { described_class.safely(scope) { raise "boom" } }
          .to output(/Error creating task: boom/).to_stderr
      end

      context "with a custom_message override" do
        subject(:result) do
          silence_stderr do
            described_class.safely("in some_tool", custom_message: "Friendly hint.") { raise "boom" }
          end
        end

        it "uses the custom message in the user-facing envelope" do
          expect(result[:content].first[:text]).to eq("Friendly hint.")
        end

        it "still warns with the default \"Error <scope>: <e.message>\" line" do
          expect do
            described_class.safely("in some_tool", custom_message: "Friendly hint.") { raise "boom" }
          end.to output(/Error in some_tool: boom/).to_stderr
        end
      end
    end

    context "when the block raises outside StandardError" do
      it "does not rescue the error" do
        expect { described_class.safely("doing stuff") { raise Exception, "nope" } } # rubocop:disable Lint/RaiseException
          .to raise_error(Exception, "nope")
      end
    end
  end
end
