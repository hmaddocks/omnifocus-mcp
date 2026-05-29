# frozen_string_literal: true

require "omnifocus_mcp/resources/today_resource"

RSpec.describe OmnifocusMcp::Resources::TodayResource do
  subject(:resource) { described_class.new }

  let(:match) { OmnifocusMcp::Tools::Operations::QueryOmnifocus::Match }

  before { allow(OmnifocusMcp).to receive(:logger).and_return(instance_double(Logger, warn: nil)) }

  def ok_match(items)
    OmnifocusMcp::Result.ok(match.new(items: items, count: items.length))
  end

  context "metadata" do
    it "exposes the canonical URI" do
      expect(described_class.uri).to eq("omnifocus://today")
    end

    it "exposes the canonical resource name" do
      expect(described_class.resource_name).to eq("today")
    end

    it "describes itself with the expected metadata" do
      expect(described_class.description).to eq(
        "Today's agenda — tasks due today, planned for today, and overdue items"
      )
    end

    it "is a fixed (non-templated) resource" do
      expect(described_class.templated?).to be false
    end

    it "requests the documented due field set" do
      expect(described_class::DUE_FIELDS).to eq(
        %w[id name flagged dueDate projectName tagNames taskStatus]
      )
    end

    it "requests the documented planned field set" do
      expect(described_class::PLANNED_FIELDS).to eq(
        %w[id name flagged plannedDate projectName tagNames taskStatus]
      )
    end

    it "uses the due field set for overdue queries" do
      expect(described_class::OVERDUE_FIELDS).to eq(described_class::DUE_FIELDS)
    end
  end

  describe "#payload" do
    subject(:payload) { resource.payload }

    context "when all queries succeed" do
      let(:due) { [{ "id" => "d1", "dueDate" => "2026-05-23" }] }
      let(:planned) { [{ "id" => "p1", "plannedDate" => "2026-05-23" }] }
      let(:overdue) { [{ "id" => "o1", "taskStatus" => "Overdue" }] }
      let(:expected_payload) do
        {
          due_today: [{ id: "d1", due_date: "2026-05-23" }],
          planned_today: [{ id: "p1", planned_date: "2026-05-23" }],
          overdue: [{ id: "o1", task_status: "Overdue" }]
        }
      end

      before do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call) do |params|
          case params.filters
          when { due_on: 0 }           then ok_match(due)
          when { planned_on: 0 }       then ok_match(planned)
          when { status: ["Overdue"] } then ok_match(overdue)
          end
        end
      end

      it "queries tasks due today with the documented fields" do
        expect(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call).with(
          an_object_having_attributes(
            entity: "tasks",
            filters: { due_on: 0 },
            fields: described_class::DUE_FIELDS
          )
        ).and_return(ok_match(due))

        payload
      end

      it "queries tasks planned today with the documented fields" do
        expect(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call).with(
          an_object_having_attributes(
            entity: "tasks",
            filters: { planned_on: 0 },
            fields: described_class::PLANNED_FIELDS
          )
        ).and_return(ok_match(planned))

        payload
      end

      it "queries overdue tasks with the documented fields" do
        expect(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call).with(
          an_object_having_attributes(
            entity: "tasks",
            filters: { status: ["Overdue"] },
            fields: described_class::OVERDUE_FIELDS
          )
        ).and_return(ok_match(overdue))

        payload
      end

      it "bundles results under the expected keys" do
        expect(payload).to eq(expected_payload)
      end

      it "runs queries in due, planned, overdue order" do
        captured_filters = []
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call) do |params|
          captured_filters << params.filters
          ok_match([])
        end

        payload

        expect(captured_filters).to eq(
          [{ due_on: 0 }, { planned_on: 0 }, { status: ["Overdue"] }]
        )
      end
    end

    context "when queries succeed and fail independently" do
      let(:due) { [{ "id" => "d1", "dueDate" => "2026-05-23" }] }
      let(:overdue) { [{ "id" => "o1", "taskStatus" => "Overdue" }] }
      let(:expected_payload) do
        {
          due_today: [{ id: "d1", due_date: "2026-05-23" }],
          planned_today: [],
          overdue: [{ id: "o1", task_status: "Overdue" }]
        }
      end

      before do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call) do |params|
          case params.filters
          when { due_on: 0 }           then ok_match(due)
          when { planned_on: 0 }       then OmnifocusMcp::Result.error("planned failed")
          when { status: ["Overdue"] } then ok_match(overdue)
          end
        end
      end

      it "returns items only for successful sections" do
        expect(payload).to eq(expected_payload)
      end
    end

    context "when every query fails" do
      before do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
          .and_return(OmnifocusMcp::Result.error("nope"))
      end

      it "falls back to empty arrays for every section" do
        expect(payload).to eq(
          due_today: [],
          planned_today: [],
          overdue: []
        )
      end
    end

    context "when a query succeeds with nil items" do
      before do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
          .and_return(OmnifocusMcp::Result.ok(match.new(items: nil, count: 0)))
      end

      it "falls back to empty arrays for every section" do
        expect(payload).to eq(
          due_today: [],
          planned_today: [],
          overdue: []
        )
      end
    end
  end

  describe "#content" do
    subject(:content) { resource.content }

    context "when all queries succeed" do
      before do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call) do |params|
          case params.filters
          when { due_on: 0 }           then ok_match([{ "id" => "d1" }])
          when { planned_on: 0 }       then ok_match([{ "id" => "p1" }])
          when { status: ["Overdue"] } then ok_match([{ "id" => "o1" }])
          end
        end
      end

      it "renders camelCase JSON keys" do
        parsed_content = JSON.parse(content, symbolize_names: true)

        expect(parsed_content).to eq(
          dueToday: [{ id: "d1" }],
          plannedToday: [{ id: "p1" }],
          overdue: [{ id: "o1" }]
        )
      end
    end

    context "when every query fails" do
      before do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
          .and_return(OmnifocusMcp::Result.error("nope"))
      end

      it "pretty-prints empty arrays for every section" do
        parsed_content = JSON.parse(content, symbolize_names: true)

        expect(parsed_content).to eq(dueToday: [], plannedToday: [], overdue: [])
      end
    end
  end
end
