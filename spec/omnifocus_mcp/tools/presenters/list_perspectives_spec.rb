# frozen_string_literal: true

require "omnifocus_mcp/tools/presenters/list_perspectives"

RSpec.describe OmnifocusMcp::Tools::Presenters::ListPerspectives do
  describe ".format" do
    subject(:output) { described_class.format(perspectives) }

    let(:perspectives) do
      [
        { "name" => "Inbox", "type" => "builtin" },
        { "name" => "Review", "type" => "custom" }
      ]
    end

    it "groups built-in and custom perspectives" do
      expect(output).to include("### Built-in Perspectives\n• Inbox\n\n### Custom Perspectives\n• Review")
    end
  end
end
