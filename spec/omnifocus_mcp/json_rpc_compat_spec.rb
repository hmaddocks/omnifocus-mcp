# frozen_string_literal: true

require "omnifocus_mcp/json_rpc_compat"

RSpec.describe OmnifocusMcp::JsonRpcCompat do
  describe ".normalize_line" do
    subject(:normalized) { described_class.normalize_line(line) }

    context "when the line is US-ASCII-labelled but contains UTF-8 bytes" do
      let(:line) { "#{'{"name":"café"}'.b.force_encoding(Encoding::US_ASCII)}\n" }

      it "returns the stripped UTF-8 string" do
        expect(normalized).to eq('{"name":"café"}')
      end
    end

    context "when the line is blank after stripping" do
      let(:line) { "  \n" }

      it "returns an empty string" do
        expect(normalized).to eq("")
      end
    end
  end
end
