# frozen_string_literal: true

require "omnifocus_mcp/utils/date_formatting"

RSpec.describe OmnifocusMcp::Utils::DateFormatting do
  it "is a deprecated alias for Infrastructure::AppleScriptDateBuilder" do
    expect(described_class).to equal(OmnifocusMcp::Infrastructure::AppleScriptDateBuilder)
  end
end
