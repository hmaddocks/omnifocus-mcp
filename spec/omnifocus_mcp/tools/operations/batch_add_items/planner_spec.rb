# frozen_string_literal: true

require "omnifocus_mcp/tools/operations/batch_add_items/planner"

RSpec.describe OmnifocusMcp::Tools::Operations::BatchAddItems::Planner do
  def batch_item(payload, index:)
    OmnifocusMcp::Tools::Operations::BatchAddItems::BatchItem.new(
      payload: OmnifocusMcp::Tools::Params::BatchAddItemParams.from_hash(payload),
      index: index
    )
  end

  describe "#prepare!" do
    context "with a cycle in temp_id graph" do
      subject(:planner) { described_class.new(batch_items) }

      let(:batch_items) do
        [
          batch_item({ type: "task", name: "A", temp_id: "a", parent_temp_id: "b" }, index: 0),
          batch_item({ type: "task", name: "B", temp_id: "b", parent_temp_id: "a" }, index: 1)
        ]
      end

      it "fails cycle participants before processing" do
        planner.prepare!

        expect(batch_items.map(&:pending?)).to eq([false, false])
      end

      it "records a cycle error on the participant" do
        planner.prepare!

        expect(batch_items.first.result.error).to start_with("Cycle detected:")
      end
    end

    context "with an unknown parent_temp_id and no explicit parent_task_id" do
      subject(:planner) { described_class.new(batch_items) }

      let(:batch_items) do
        [
          batch_item({ type: "task", name: "Orphan", parent_temp_id: "ghost" }, index: 0)
        ]
      end

      it "fails the item up front" do
        planner.prepare!

        expect(batch_items.first.result.error).to eq("Unknown parentTempId: ghost")
      end
    end
  end

  describe "#processing_order" do
    context "with hierarchy levels and original indices" do
      subject(:order) { described_class.new(batch_items).processing_order }

      let(:batch_items) do
        [
          batch_item({ type: "task", name: "Child", hierarchy_level: 1 }, index: 0),
          batch_item({ type: "task", name: "Parent", hierarchy_level: 0 }, index: 1),
          batch_item({ type: "task", name: "Sibling" }, index: 2)
        ]
      end

      it "sorts by hierarchy level then original index" do
        expect(order.map { |item| item.payload.name }).to eq(%w[Parent Sibling Child])
      end
    end
  end

  describe "#resolve_task_parent" do
    context "when the parent temp id has not resolved yet" do
      subject(:resolution) { planner.resolve_task_parent(payload) }

      let(:planner) { described_class.new([]) }
      let(:payload) do
        OmnifocusMcp::Tools::Params::BatchAddItemParams.from_hash(
          type: "task",
          name: "Child",
          parent_temp_id: "parent"
        )
      end

      it "reports that the task is not ready" do
        expect(resolution).to eq([nil, nil, false])
      end
    end

    context "when the parent temp id resolved to a project" do
      subject(:resolution) { planner.resolve_task_parent(payload) }

      let(:planner) { described_class.new([]) }
      let(:payload) do
        OmnifocusMcp::Tools::Params::BatchAddItemParams.from_hash(
          type: "task",
          name: "Child",
          parent_temp_id: "project-temp"
        )
      end

      before do
        planner.record_resolution(
          payload: OmnifocusMcp::Tools::Params::BatchAddItemParams.from_hash(
            type: "project",
            name: "Launch",
            temp_id: "project-temp"
          ),
          id: "P1",
          type: "project"
        )
      end

      it "uses the resolved project name" do
        expect(resolution).to eq([nil, "Launch", true])
      end
    end

    context "when the parent temp id resolved to a task" do
      subject(:resolution) { planner.resolve_task_parent(payload) }

      let(:planner) { described_class.new([]) }
      let(:payload) do
        OmnifocusMcp::Tools::Params::BatchAddItemParams.from_hash(
          type: "task",
          name: "Child",
          project_name: "Inbox",
          parent_temp_id: "task-temp"
        )
      end

      before do
        planner.record_resolution(
          payload: OmnifocusMcp::Tools::Params::BatchAddItemParams.from_hash(
            type: "task",
            name: "Parent",
            temp_id: "task-temp"
          ),
          id: "T1",
          type: "task"
        )
      end

      it "uses the resolved task id" do
        expect(resolution).to eq(["T1", "Inbox", true])
      end
    end
  end

  describe "#finalize_unresolved!" do
    context "with a still-pending dependent item" do
      subject(:planner) { described_class.new(batch_items) }

      let(:batch_items) do
        [
          batch_item({ type: "task", name: "Child", parent_temp_id: "parent" }, index: 0)
        ]
      end

      it "fails the item with an unresolved parent message" do
        planner.finalize_unresolved!

        expect(batch_items.first.result.error).to eq("Unresolved parentTempId: parent")
      end
    end
  end
end
