# frozen_string_literal: true

require "omnifocus_mcp/tools/operations/batch_add_items/bulk_executor"

RSpec.describe OmnifocusMcp::Tools::Operations::BatchAddItems::BulkExecutor do
  subject(:bulk_results) do
    described_class.run(batch_items, execute_applescript: execute_applescript)
  end

  let(:batch_items) do
    [
      OmnifocusMcp::Tools::Operations::BatchAddItems::BatchItem.new(
        payload: OmnifocusMcp::Tools::Params::BatchAddItemParams.from_hash(type: "task", name: "One"),
        index: 0
      ),
      OmnifocusMcp::Tools::Operations::BatchAddItems::BatchItem.new(
        payload: OmnifocusMcp::Tools::Params::BatchAddItemParams.from_hash(type: "task", name: "Two"),
        index: 1
      )
    ]
  end

  let(:execute_applescript) do
    lambda do |_script|
      [
        '{"success":true,"items":[{"taskId":"T1","placement":"inbox"},{"taskId":"T2","placement":"project"}]}',
        "",
        instance_double(Process::Status, success?: true)
      ]
    end
  end

  describe ".eligible?" do
    it "accepts independent task batches" do
      expect(described_class.eligible?(batch_items)).to be(true)
    end

    it "rejects batches with parent_temp_id" do
      payload = OmnifocusMcp::Tools::Params::BatchAddItemParams.from_hash(
        type: "task", name: "Child", parent_temp_id: "p1"
      )
      item = OmnifocusMcp::Tools::Operations::BatchAddItems::BatchItem.new(payload: payload, index: 0)

      expect(described_class.eligible?([item])).to be(false)
    end

    it "rejects project items" do
      payload = OmnifocusMcp::Tools::Params::BatchAddItemParams.from_hash(type: "project", name: "Launch")
      item = OmnifocusMcp::Tools::Operations::BatchAddItems::BatchItem.new(payload: payload, index: 0)

      expect(described_class.eligible?([item])).to be(false)
    end
  end

  describe ".run" do
    it "returns per-item ok results from one AppleScript response" do
      expect(bulk_results.map(&:ok)).to eq(%w[T1 T2])
    end

    context "when osascript exits non-zero" do
      let(:execute_applescript) do
        ->(_script) { ["", "permission denied", instance_double(Process::Status, success?: false, exitstatus: 1)] }
      end

      it "returns nil so the caller can fall back to sequential adds" do
        expect(bulk_results).to be_nil
      end
    end

    context "when the response item count does not match" do
      let(:status_success) { instance_double(Process::Status, success?: true) }
      let(:execute_applescript) do
        json = '{"success":true,"items":[{"taskId":"T1","placement":"inbox"}]}'
        ->(_script) { [json, "", status_success] }
      end

      it "returns nil" do
        expect(bulk_results).to be_nil
      end
    end
  end
end
