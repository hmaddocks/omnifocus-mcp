# frozen_string_literal: true

require "omnifocus_mcp/resources/flagged_resource"

RSpec.describe OmnifocusMcp::Resources::FlaggedResource do
  subject(:resource) { described_class.new }

  let(:match) { OmnifocusMcp::Tools::Operations::QueryOmnifocus::Match }

  before { allow(OmnifocusMcp).to receive(:logger).and_return(instance_double(Logger, warn: nil)) }

  context "metadata" do
    it "exposes the canonical URI" do
      expect(described_class.uri).to eq("omnifocus://flagged")
    end

    it "exposes the canonical resource name" do
      expect(described_class.resource_name).to eq("flagged")
    end

    it "describes itself with the expected metadata" do
      expect(described_class.description).to eq("All flagged OmniFocus items")
    end

    it "is a fixed (non-templated) resource" do
      expect(described_class.templated?).to be false
    end

    it "requests the documented field set" do
      expect(described_class::FIELDS).to eq(%w[id name dueDate projectName tagNames taskStatus])
    end
  end

  describe "#payload" do
    subject(:payload) { resource.payload }

    context "when the query succeeds" do
      let(:query_result) { OmnifocusMcp::Result.ok(match.new(items: items, count: items.to_a.length)) }

      context "with flagged items" do
        let(:items) { [{ "id" => "f1", "name" => "Important", "projectName" => "Work", "taskStatus" => "Next" }] }
        let(:expected_items) { [{ id: "f1", name: "Important", project_name: "Work", task_status: "Next" }] }

        it "queries with flagged: true" do
          expect(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call).with(
            an_object_having_attributes(
              entity: "tasks",
              filters: { flagged: true },
              fields: described_class::FIELDS
            )
          ).and_return(query_result)

          payload
        end

        it "returns flagged task items" do
          allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
            .and_return(query_result)

          expect(payload).to eq(expected_items)
        end
      end

      context "when items is nil" do
        let(:items) { nil }

        before do
          allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
            .and_return(query_result)
        end

        it "returns an empty array" do
          expect(payload).to eq([])
        end
      end

      context "when items is an empty array" do
        let(:items) { [] }

        before do
          allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
            .and_return(query_result)
        end

        it "returns an empty array" do
          expect(payload).to eq([])
        end
      end
    end

    context "when the query fails" do
      before do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
          .and_return(OmnifocusMcp::Result.error("boom"))
      end

      it "returns an error envelope hash" do
        expect(payload).to eq({ error: "boom" })
      end
    end
  end

  describe "#content" do
    subject(:content) { resource.content }

    context "when the query succeeds" do
      let(:items) { [{ "id" => "f1", "name" => "Important", "projectName" => "Work", "taskStatus" => "Next" }] }

      before do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
          .and_return(OmnifocusMcp::Result.ok(match.new(items: items, count: items.length)))
      end

      it "pretty-prints the payload as JSON" do
        expect(content).to eq(JSON.pretty_generate(items))
      end
    end

    context "when the query fails" do
      before do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
          .and_return(OmnifocusMcp::Result.error("boom"))
      end

      it "pretty-prints the error envelope as JSON" do
        expect(content).to eq(JSON.pretty_generate(error: "boom"))
      end
    end
  end
end
