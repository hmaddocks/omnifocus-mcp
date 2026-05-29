# frozen_string_literal: true

require "omnifocus_mcp/tools/query_omnifocus_formatter"

RSpec.describe OmnifocusMcp::Tools::QueryOmnifocusFormatter do
  it "is a deprecated alias for Presenters::QueryResults" do
    expect(described_class).to equal(OmnifocusMcp::Tools::Presenters::QueryResults)
  end
end
