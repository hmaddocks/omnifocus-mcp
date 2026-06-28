# frozen_string_literal: true

require "omnifocus_mcp/tools/presenters/perspective_view"

RSpec.describe OmnifocusMcp::Tools::Presenters::PerspectiveView do
  describe ".format" do
    subject(:output) { described_class.format("Today", items, 1) }

    let(:items) do
      [
        {
          "id" => "t1",
          "name" => "Ship",
          "flagged" => true,
          "projectName" => "Work",
          "estimatedMinutes" => 90
        }
      ]
    end

    it "renders visible perspective items with limit warning" do
      expect(output).to include("## Today Perspective (1 items)\n\n• ☐ 🚩 Ship (Work) (1h30m) [t1]")
    end
  end
end
