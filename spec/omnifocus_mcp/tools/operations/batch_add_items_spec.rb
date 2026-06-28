# frozen_string_literal: true

require "omnifocus_mcp/tools/operations/batch_add_items"
require "omnifocus_mcp/tools/operations/batch_remove_items"

RSpec.describe OmnifocusMcp::Tools::Operations::BatchAddItems do
  describe ".call" do
    subject(:result) do
      described_class.call(
        [{ type: "task", name: "Buy milk" }],
        add_task: add_task,
        add_project: ->(_) { raise "should not be called" },
        bulk_executor: bulk_executor
      )
    end

    let(:created) { OmnifocusMcp::Tools::Operations::AddOmniFocusTask::Created }
    let(:captured) { [] }
    let(:add_task) do
      lambda do |params|
        captured << params
        OmnifocusMcp::Result.ok(created.new(task_id: "T1", placement: "inbox"))
      end
    end
    let(:bulk_executor) { BatchOperationBulkSkip.new }

    it "returns per-item result arrays unchanged" do
      expect(result.ok.first.ok).to eq("T1")
    end

    it "passes typed task params to the injected add operation" do
      result
      expect(captured.first.name).to eq("Buy milk")
    end
  end
end

class BatchOperationBulkSkip
  def run(*)
    nil
  end
end
