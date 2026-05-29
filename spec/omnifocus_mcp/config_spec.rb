# frozen_string_literal: true

require "omnifocus_mcp/config"

RSpec.describe OmnifocusMcp::Config do
  around do |example|
    original = ENV.fetch("OMNIFOCUS_MCP_SCRIPT_TIMEOUT_SEC", nil)
    example.run
  ensure
    if original.nil?
      ENV.delete("OMNIFOCUS_MCP_SCRIPT_TIMEOUT_SEC")
    else
      ENV["OMNIFOCUS_MCP_SCRIPT_TIMEOUT_SEC"] = original
    end
  end

  describe ".script_timeout_sec" do
    it "defaults to 180 seconds" do
      ENV.delete("OMNIFOCUS_MCP_SCRIPT_TIMEOUT_SEC")

      expect(described_class.script_timeout_sec).to eq(180)
    end

    it "reads a positive integer from the environment" do
      ENV["OMNIFOCUS_MCP_SCRIPT_TIMEOUT_SEC"] = "60"

      expect(described_class.script_timeout_sec).to eq(60)
    end

    it "returns nil when set to 0 (disable timeout)" do
      ENV["OMNIFOCUS_MCP_SCRIPT_TIMEOUT_SEC"] = "0"

      expect(described_class.script_timeout_sec).to be_nil
    end
  end
end
