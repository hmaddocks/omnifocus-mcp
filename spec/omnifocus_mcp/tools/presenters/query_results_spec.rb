# frozen_string_literal: true

require "omnifocus_mcp/tools/presenters/query_results"

RSpec.describe OmnifocusMcp::Tools::Presenters::QueryResults do
  describe ".format_filters" do
    context "with relative date windows" do
      subject(:result) { described_class.format_filters(filters) }

      let(:filters) { { plannedWithin: 7, dueWithin: 3 } }

      it "includes plannedWithin in the filter summary" do
        expect(result).to include("planned within 7 days")
      end

      it "includes dueWithin in the filter summary" do
        expect(result).to include("due within 3 days")
      end
    end

    context "with boolean filters set to false" do
      it "renders flagged: false" do
        expect(described_class.format_filters(flagged: false)).to eq("flagged: false")
      end

      it "renders hasNote: false" do
        expect(described_class.format_filters(hasNote: false)).to eq("has note: false")
      end

      it "renders isRepeating: false" do
        expect(described_class.format_filters(isRepeating: false)).to eq("repeating: false")
      end
    end

    context "with named date filters" do
      subject(:result) { described_class.format_filters(filters) }

      let(:filters) { { dueWithin: "this week" } }

      it "renders the named date filter as a string" do
        expect(result).to eq("due within this week")
      end
    end

    context "with common tool-layer filter keys" do
      subject(:result) { described_class.format_filters(filters) }

      let(:filters) do
        {
          projectName: "Errands",
          taskName: "email",
          tags: ["Work"],
          status: ["Next"],
          flagged: true,
          inbox: false,
          deferredUntil: 3,
          completedWithin: 7
        }
      end

      it "renders the project name filter" do
        expect(result).to include('project: "Errands"')
      end

      it "renders the task name filter" do
        expect(result).to include('task: "email"')
      end

      it "renders the tag filter" do
        expect(result).to include("tags: [Work]")
      end

      it "renders the status filter" do
        expect(result).to include("status: [Next]")
      end

      it "renders the flagged filter" do
        expect(result).to include("flagged: true")
      end

      it "renders the inbox filter" do
        expect(result).to include("inbox: false")
      end

      it "renders the deferred window filter" do
        expect(result).to include("deferred becoming available within 3 days")
      end

      it "renders the completed window filter" do
        expect(result).to include("completed within 7 days")
      end
    end
  end

  describe ".format_task" do
    context "with a richly populated task" do
      subject(:result) { described_class.format_task(task) }

      let(:task) do
        {
          "name" => "Deep work",
          "id" => "T1",
          "flagged" => true,
          "tagNames" => %w[Work Focus],
          "estimatedMinutes" => 90,
          "taskStatus" => "Next",
          "note" => "Prep slides"
        }
      end

      it "includes the flag and id" do
        expect(result).to include("• 🚩 Deep work [T1]")
      end

      it "includes the tags" do
        expect(result).to include("<Work,Focus>")
      end

      it "includes the duration" do
        expect(result).to include("(1h)")
      end

      it "includes the task status" do
        expect(result).to include("#next")
      end

      it "renders notes on a separate indented line" do
        expect(result).to include("\n  Note: Prep slides")
      end
    end
  end

  describe ".format_query_results" do
    context "when items are nil" do
      subject(:result) { described_class.format_query_results(items: nil, entity: "tasks") }

      it "returns the empty message" do
        expect(result).to eq("No tasks found matching the specified criteria.")
      end
    end

    context "when there are no items" do
      subject(:result) { described_class.format_query_results(items: [], entity: "tasks") }

      it "returns the empty message" do
        expect(result).to eq("No tasks found matching the specified criteria.")
      end
    end

    context "when formatting tasks" do
      subject(:result) { described_class.format_query_results(items:, entity: "tasks", filters:) }

      let(:items) { [{ "name" => "Email", "id" => "T1", "dueDate" => "2026-05-23T12:00:00Z" }] }
      let(:filters) { { taskName: "email" } }

      it "includes a header with the result count" do
        expect(result).to start_with("## Query Results: 1 tasks")
      end

      it "includes the filter summary" do
        expect(result).to include('Filters applied: task: "email"')
      end

      it "formats each task line" do
        expect(result).to include("• Email [T1] [due: 2026-05-23]")
      end
    end

    context "when formatting projects" do
      subject(:result) { described_class.format_query_results(items:, entity: "projects") }

      let(:items) { [{ "name" => "Launch", "status" => "Active", "taskCount" => 2 }] }

      it "includes a header with the project count" do
        expect(result).to start_with("## Query Results: 1 projects")
      end

      it "formats each project line" do
        expect(result).to include("P: Launch (2 tasks)")
      end
    end

    context "when formatting folders" do
      subject(:result) { described_class.format_query_results(items:, entity: "folders") }

      let(:items) { [{ "name" => "Work", "projectCount" => 2, "path" => "Top/Work" }] }

      it "includes a header with the folder count" do
        expect(result).to start_with("## Query Results: 1 folders")
      end

      it "formats each folder line" do
        expect(result).to include("F: Work (2 projects) 📍 Top/Work")
      end
    end

    context "when the entity type is unsupported" do
      subject(:result) { described_class.format_query_results(items:, entity: "bogus") }

      let(:items) { [{ "name" => "X" }] }

      it "includes an unsupported-entity message" do
        expect(result).to include("Unsupported entity: bogus")
      end
    end
  end

  describe ".format_project" do
    subject(:result) { described_class.format_project(project) }

    let(:project) { { "name" => "Launch", "status" => "OnHold", "taskCount" => 4, "folderName" => "Work" } }

    it "renders project name, status, folder, and task count" do
      expect(result).to eq("P: Launch [OnHold] 📁 Work (4 tasks)")
    end
  end

  describe ".format_folder" do
    subject(:result) { described_class.format_folder(folder) }

    let(:folder) { { "name" => "Work", "projectCount" => 2, "path" => "Top/Work" } }

    it "renders folder name, project count, and path" do
      expect(result).to eq("F: Work (2 projects) 📍 Top/Work")
    end
  end
end
