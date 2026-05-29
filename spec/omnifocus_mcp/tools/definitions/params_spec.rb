# frozen_string_literal: true

require "omnifocus_mcp/tools/params"

RSpec.describe OmnifocusMcp::Tools::Params do
  describe OmnifocusMcp::Tools::Params::McpBoundary do
    let(:sample_klass) { Data.define(:due_date, :parent_task_id) }

    describe ".build" do
      subject(:result) { described_class.build(sample_klass, { dueDate: "2026-05-23", parentTaskId: "T1" }) }

      it "rewrites camelCase MCP keys to snake_case struct members" do
        expect(result).to eq(sample_klass.new(due_date: "2026-05-23", parent_task_id: "T1"))
      end
    end

    describe ".build with deep: true" do
      let(:nested_klass) { Data.define(:filters) }

      it "recurses into nested Hashes" do
        result = described_class.build(nested_klass, { filters: { dueDate: "2026-05-23" } }, deep: true)

        expect(result.filters).to eq(due_date: "2026-05-23")
      end
    end
  end

  describe "AddTaskParams.from_mcp" do
    subject(:params) do
      described_class::AddTaskParams.from_mcp(
        name: "X", note: "details", flagged: true, tags: %w[home],
        dueDate: "2026-05-23", deferDate: "2026-05-22", plannedDate: "2026-05-21",
        estimatedMinutes: 30, projectName: "P", parentTaskId: "PT", parentTaskName: "PN",
        hierarchyLevel: 2
      )
    end

    it "maps every camelCase field to snake_case" do
      expect(params.to_h).to include(
        name: "X",
        note: "details",
        flagged: true,
        tags: %w[home],
        due_date: "2026-05-23",
        defer_date: "2026-05-22",
        planned_date: "2026-05-21",
        estimated_minutes: 30,
        project_name: "P",
        parent_task_id: "PT",
        parent_task_name: "PN",
        hierarchy_level: 2
      )
    end
  end

  describe "AddProjectParams.from_mcp" do
    subject(:params) do
      described_class::AddProjectParams.from_mcp(
        name: "P", dueDate: "2026-05-23", folderName: "Work", estimatedMinutes: 15, sequential: true
      )
    end

    it "maps camelCase fields to snake_case" do
      expect(params.to_h).to include(
        name: "P", due_date: "2026-05-23", folder_name: "Work",
        estimated_minutes: 15, sequential: true
      )
    end
  end

  describe "EditItemParams.from_mcp" do
    subject(:params) do
      described_class::EditItemParams.from_mcp(
        id: "1", name: "Old", itemType: "task",
        newName: "New", newDueDate: "2026-05-23", addTags: %w[urgent],
        newProjectName: "Inbox", newSequential: true
      )
    end

    it "maps every camelCase edit field to snake_case" do
      expect(params.to_h).to include(
        id: "1", name: "Old", item_type: "task",
        new_name: "New", new_due_date: "2026-05-23", add_tags: %w[urgent],
        new_project_name: "Inbox", new_sequential: true
      )
    end
  end

  describe "RemoveItemParams.from_mcp" do
    subject(:params) { described_class::RemoveItemParams.from_mcp(id: "1", itemType: "task") }

    it "maps itemType to item_type" do
      expect(params.to_h).to eq(id: "1", name: nil, item_type: "task")
    end
  end

  describe "QueryOmnifocusParams.from_mcp" do
    subject(:params) do
      described_class::QueryOmnifocusParams.from_mcp(
        entity: "tasks",
        filters: { projectName: "Errands", dueWithin: "today" },
        sortBy: "dueDate", sortOrder: "asc", includeCompleted: true, format: "json"
      )
    end

    it "deep-snake_cases nested filters" do
      expect(params.filters).to eq(project_name: "Errands", due_within: "today")
    end

    it "maps top-level camelCase fields to snake_case" do
      expect(params.to_h).to include(
        entity: "tasks", sort_by: "dueDate", sort_order: "asc", include_completed: true, format: "json"
      )
    end
  end

  describe "BatchAddItemParams.from_mcp" do
    subject(:params) do
      described_class::BatchAddItemParams.from_mcp(
        type: "task", name: "T", parentTaskId: "P", tempId: "t1", parentTempId: "p1"
      )
    end

    it "maps batch item camelCase keys to snake_case" do
      expect(params.to_h).to include(
        type: "task", name: "T", parent_task_id: "P", temp_id: "t1", parent_temp_id: "p1"
      )
    end

    it "rewrites String-keyed nested item hashes from fast-mcp" do
      params = described_class::BatchAddItemParams.from_mcp(
        "type" => "task", "parentTaskId" => "P", "name" => "T"
      )

      expect(params.to_h).to include(type: "task", parent_task_id: "P", name: "T")
    end
  end

  describe "BatchRemoveItemParams.from_mcp" do
    subject(:params) { described_class::BatchRemoveItemParams.from_mcp(id: "1", itemType: "project") }

    it "maps itemType to item_type" do
      expect(params.to_h).to eq(id: "1", name: nil, item_type: "project")
    end
  end

  describe "ListPerspectivesParams.from_mcp" do
    it "defaults both include flags to true" do
      params = described_class::ListPerspectivesParams.from_mcp({})

      expect(params.to_h).to eq(include_built_in: true, include_custom: true)
    end

    it "maps camelCase filter flags to snake_case" do
      params = described_class::ListPerspectivesParams.from_mcp(includeBuiltIn: false, includeCustom: true)

      expect(params.to_h).to eq(include_built_in: false, include_custom: true)
    end
  end

  describe "ListTagsParams.from_mcp" do
    it "defaults include_dropped to false" do
      params = described_class::ListTagsParams.from_mcp({})

      expect(params.include_dropped).to be false
    end

    it "maps includeDropped to include_dropped" do
      params = described_class::ListTagsParams.from_mcp(includeDropped: true)

      expect(params.include_dropped).to be true
    end
  end

  describe "GetPerspectiveViewParams.from_mcp" do
    subject(:params) do
      described_class::GetPerspectiveViewParams.from_mcp(
        perspectiveName: "Inbox", limit: 50, fields: %w[id name]
      )
    end

    it "maps perspectiveName to perspective_name" do
      expect(params.to_h).to eq(perspective_name: "Inbox", limit: 50, fields: %w[id name])
    end
  end
end
