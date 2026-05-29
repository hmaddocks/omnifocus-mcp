# frozen_string_literal: true

require "omnifocus_mcp/utils/apple_script_envelope"

RSpec.describe OmnifocusMcp::Utils::AppleScriptEnvelope do
  it "is a deprecated alias for Parsers::AppleScriptEnvelope" do
    expect(described_class).to equal(OmnifocusMcp::Parsers::AppleScriptEnvelope)
  end
end
