# frozen_string_literal: true

require "omnifocus_mcp/resources/stats_resource"

RSpec.describe OmnifocusMcp::Resources::StatsResource do
  subject(:resource) { described_class.new }

  let(:stats) do
    {
      "taskCount" => 1234,
      "activeTaskCount" => 200,
      "projectCount" => 42,
      "activeProjectCount" => 30,
      "folderCount" => 5,
      "tagCount" => 12,
      "overdueCount" => 3,
      "nextActionCount" => 8,
      "flaggedCount" => 2,
      "inboxCount" => 6,
      "lastModified" => "2025-01-02T03:04:05.000Z"
    }
  end
  let(:snake_stats) do
    {
      task_count: 1234,
      active_task_count: 200,
      project_count: 42,
      active_project_count: 30,
      folder_count: 5,
      tag_count: 12,
      overdue_count: 3,
      next_action_count: 8,
      flagged_count: 2,
      inbox_count: 6,
      last_modified: "2025-01-02T03:04:05.000Z"
    }
  end

  context "metadata" do
    it "exposes the canonical URI" do
      expect(described_class.uri).to eq("omnifocus://stats")
    end

    it "exposes the canonical resource name" do
      expect(described_class.resource_name).to eq("stats")
    end

    it "describes itself with the expected metadata" do
      expect(described_class.description).to eq("Quick OmniFocus database statistics overview")
    end

    it "is a fixed (non-templated) resource" do
      expect(described_class.templated?).to be false
    end
  end

  describe "#payload" do
    subject(:payload) { resource.payload }

    context "when DatabaseStats succeeds" do
      before do
        allow(OmnifocusMcp::Tools::Operations::DatabaseStats).to receive(:get_database_stats)
          .and_return(OmnifocusMcp::Result.ok(stats))
      end

      it "delegates to get_database_stats" do
        expect(OmnifocusMcp::Tools::Operations::DatabaseStats).to receive(:get_database_stats)
          .and_return(OmnifocusMcp::Result.ok(stats))

        payload
      end

      it "returns the stats hash" do
        expect(payload).to eq(snake_stats)
      end

      it "returns the documented database stats fields" do
        expect(payload.keys).to contain_exactly(
          :task_count,
          :active_task_count,
          :project_count,
          :active_project_count,
          :folder_count,
          :tag_count,
          :overdue_count,
          :next_action_count,
          :flagged_count,
          :inbox_count,
          :last_modified
        )
      end
    end

    context "when DatabaseStats returns nil stats" do
      let(:successful_with_nil_stats) do
        instance_double(OmnifocusMcp::Result).tap do |result|
          allow(result).to receive(:fold) do |on_ok:, **|
            on_ok.call(nil)
          end
        end
      end

      before do
        allow(OmnifocusMcp::Tools::Operations::DatabaseStats).to receive(:get_database_stats)
          .and_return(successful_with_nil_stats)
      end

      it "returns an empty hash" do
        expect(payload).to eq({})
      end
    end

    context "when DatabaseStats fails" do
      before do
        allow(OmnifocusMcp::Tools::Operations::DatabaseStats).to receive(:get_database_stats)
          .and_return(OmnifocusMcp::Result.error("boom"))
      end

      it "returns an error envelope hash" do
        expect(payload).to eq({ error: "boom" })
      end
    end
  end

  describe "#content" do
    subject(:content) { resource.content }

    context "when DatabaseStats succeeds" do
      before do
        allow(OmnifocusMcp::Tools::Operations::DatabaseStats).to receive(:get_database_stats)
          .and_return(OmnifocusMcp::Result.ok(stats))
      end

      it "pretty-prints the payload as JSON" do
        expect(content).to eq(JSON.pretty_generate(stats))
      end
    end

    context "when DatabaseStats returns nil stats" do
      let(:successful_with_nil_stats) do
        instance_double(OmnifocusMcp::Result).tap do |result|
          allow(result).to receive(:fold) do |on_ok:, **|
            on_ok.call(nil)
          end
        end
      end

      before do
        allow(OmnifocusMcp::Tools::Operations::DatabaseStats).to receive(:get_database_stats)
          .and_return(successful_with_nil_stats)
      end

      it "pretty-prints an empty object as JSON" do
        expect(content).to eq(JSON.pretty_generate({}))
      end
    end

    context "when DatabaseStats fails" do
      before do
        allow(OmnifocusMcp::Tools::Operations::DatabaseStats).to receive(:get_database_stats)
          .and_return(OmnifocusMcp::Result.error("boom"))
      end

      it "pretty-prints the error envelope as JSON" do
        expect(content).to eq(JSON.pretty_generate(error: "boom"))
      end
    end
  end
end
