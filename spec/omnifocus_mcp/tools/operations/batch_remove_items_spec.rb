# frozen_string_literal: true

require "omnifocus_mcp/tools/operations/batch_add_items"
require "omnifocus_mcp/tools/operations/batch_remove_items"

RSpec.describe OmnifocusMcp::Tools::Operations::BatchRemoveItems do
  describe ".call" do
    subject(:result) { described_class.call([{ item_type: "task", name: "Old Task" }], remove: remove) }

    let(:removed) { OmnifocusMcp::Tools::Operations::RemoveItem::Removed }
    let(:captured) { [] }
    let(:remove) do
      lambda do |params|
        captured << params
        OmnifocusMcp::Result.ok(removed.new(id: "T1", name: "Old Task"))
      end
    end

    it "returns per-item result arrays unchanged" do
      expect(result.ok.first.ok.id).to eq("T1")
    end

    it "passes typed remove params to the injected remove operation" do
      result
      expect(captured.first.name).to eq("Old Task")
    end
  end
end

class BatchOperationBulkSkip
  def run(*)
    nil
  end
end
