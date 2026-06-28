# frozen_string_literal: true

require "omnifocus_mcp/tools/presenters/query_reply"

RSpec.describe OmnifocusMcp::Tools::Presenters::QueryReply do
  describe ".format" do
    subject(:output) { described_class.format(args: {}, params: params, match: match) }

    let(:params) { Data.define(:entity, :summary, :limit).new("tasks", true, nil) }
    let(:match) { Data.define(:items, :count).new(items: nil, count: 3) }

    it "renders summary query replies" do
      expect(output).to eq("Found 3 tasks matching your criteria.")
    end
  end
end
