# frozen_string_literal: true

require "omnifocus_mcp/tools/presenters/list_perspectives"
require "omnifocus_mcp/tools/presenters/list_tags"
require "omnifocus_mcp/tools/presenters/perspective_view"
require "omnifocus_mcp/tools/presenters/query_reply"

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
