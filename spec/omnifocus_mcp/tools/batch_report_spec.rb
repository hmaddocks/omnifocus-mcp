# frozen_string_literal: true

require "omnifocus_mcp/tools/batch_report"

RSpec.describe OmnifocusMcp::Tools::BatchReport do
  it "is a deprecated alias for Presenters::BatchReport" do
    expect(described_class).to equal(OmnifocusMcp::Tools::Presenters::BatchReport)
  end
end
