# frozen_string_literal: true

require "omnifocus_mcp/tools/presenters/batch_report"

RSpec.describe OmnifocusMcp::Tools::Presenters::BatchReport do
  Item = Data.define(:type, :name)
  RemoveItem = Data.define(:item_type, :id, :name)
  Removed = Data.define(:name)

  describe ".format_success" do
    context "when all items succeeded" do
      subject(:report) do
        described_class.format_success(
          past_tense: "added",
          failure_verb: "add",
          results: results,
          items: items
        ) { |item_result, item| described_class.add_detail(item_result, item) }
      end

      let(:results) { [OmnifocusMcp::Result.ok("t1")] }
      let(:items) { [Item.new(type: "task", name: "Buy milk")] }

      it "summarizes the successful item count" do
        expect(report).to start_with("✅ Successfully added 1 items.")
      end

      it "includes successful item details" do
        expect(report).to include('- ✅ task: "Buy milk"')
      end
    end

    context "when some items failed" do
      subject(:report) do
        described_class.format_success(
          past_tense: "added",
          failure_verb: "add",
          results: results,
          items: items
        ) { |item_result, item| described_class.add_detail(item_result, item) }
      end

      let(:results) { [OmnifocusMcp::Result.ok("t1"), OmnifocusMcp::Result.error("boom")] }
      let(:items) { [Item.new(type: "task", name: "Buy milk"), Item.new(type: "project", name: "Launch")] }

      it "summarizes the failed item count" do
        expect(report).to include("⚠️ Failed to add 1 items.")
      end

      it "includes failed item details" do
        expect(report).to include('- ❌ project: "Launch" - Error: boom')
      end
    end
  end

  describe ".all_failed?" do
    context "when all results failed" do
      subject(:all_failed) { described_class.all_failed?(results) }

      let(:results) { [OmnifocusMcp::Result.error("boom")] }

      it "returns true" do
        expect(all_failed).to be(true)
      end
    end

    context "when results are empty" do
      subject(:all_failed) { described_class.all_failed?([]) }

      it "returns false" do
        expect(all_failed).to be(false)
      end
    end
  end

  describe ".format_failure" do
    context "when per-item results are available" do
      subject(:report) do
        described_class.format_failure(
          "outer failure",
          results: results,
          items: items
        ) { |item_result, item| described_class.add_detail(item_result, item) }
      end

      let(:results) { [OmnifocusMcp::Result.error("boom")] }
      let(:items) { [Item.new(type: "task", name: "Buy milk")] }

      it "includes processed item details" do
        expect(report).to include('- ❌ task: "Buy milk" - Error: boom')
      end
    end

    context "when no item was processed" do
      subject(:report) { described_class.format_failure("outer failure") }

      it "includes the outer failure message" do
        expect(report).to eq("Failed to process batch operation.\n\nNo items processed. outer failure")
      end
    end
  end

  describe ".remove_detail" do
    context "when the removal succeeded" do
      subject(:detail) { described_class.remove_detail(result, original) }

      let(:result) { OmnifocusMcp::Result.ok(Removed.new(name: "Old task")) }
      let(:original) { RemoveItem.new(item_type: "task", id: "t1", name: nil) }

      it "uses the removed item name" do
        expect(detail).to eq('- ✅ task: "Old task"')
      end
    end

    context "when the removal failed" do
      subject(:detail) { described_class.remove_detail(result, original) }

      let(:result) { OmnifocusMcp::Result.error("not found") }
      let(:original) { RemoveItem.new(item_type: "task", id: nil, name: "Old task") }

      it "uses the original identifier and error" do
        expect(detail).to eq("- ❌ task: Old task - Error: not found")
      end
    end
  end
end
