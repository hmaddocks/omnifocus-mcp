# frozen_string_literal: true

require "omnifocus_mcp/tools/presenters/list_tags"

RSpec.describe OmnifocusMcp::Tools::Presenters::ListTags do
  describe ".format" do
    subject(:output) { described_class.format(tags) }

    let(:tags) do
      [
        { "id" => "work", "name" => "Work", "active" => true, "taskCount" => 2 },
        { "id" => "review", "name" => "Review", "active" => false, "parentTagID" => "work" }
      ]
    end

    it "renders tags with hierarchy and counts" do
      expect(output).to include("- **Work** [2 tasks] (id: work)\n  - **Review** (inactive) (id: review)")
    end
  end
end
