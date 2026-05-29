# frozen_string_literal: true

require "omnifocus_mcp/resources/project_resource"

RSpec.describe OmnifocusMcp::Resources::ProjectResource do
  let(:match) { OmnifocusMcp::Tools::Operations::QueryOmnifocus::Match }
  let(:items) { [{ "id" => "t1", "name" => "Buy milk", "parentId" => "p1", "estimatedMinutes" => 10 }] }
  let(:snake_items) { [{ id: "t1", name: "Buy milk", parent_id: "p1", estimated_minutes: 10 }] }

  def ok_match(task_items)
    OmnifocusMcp::Result.ok(match.new(items: task_items, count: task_items.length))
  end

  context "metadata" do
    it "exposes a templated URI" do
      expect(described_class.uri).to eq("omnifocus://project/{name}")
    end

    it "marks the resource as templated" do
      expect(described_class.templated?).to be true
    end

    it "exposes the template variables" do
      expect(described_class.template_variables).to eq(%w[name])
    end

    it "exposes the canonical resource name" do
      expect(described_class.resource_name).to eq("project")
    end

    it "describes itself with the expected metadata" do
      expect(described_class.description).to eq("Tasks in a specific OmniFocus project")
    end

    it "requests the documented field set" do
      expect(described_class::FIELDS).to eq(
        %w[id name flagged dueDate deferDate taskStatus tagNames parentId note estimatedMinutes]
      )
    end
  end

  describe "#payload" do
    subject(:payload) { resource.payload }

    let(:resource) { described_class.initialize_from_uri(uri) }

    before { allow(OmnifocusMcp).to receive(:logger).and_return(instance_double(Logger, warn: nil)) }

    context "when the project resolves" do
      let(:uri) { "omnifocus://project/Errands" }
      let(:query_result) { ok_match(items) }

      it "queries by project_name" do
        expect(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call).with(
          an_object_having_attributes(
            entity: "tasks",
            filters: { project_name: "Errands" },
            fields: described_class::FIELDS
          )
        ).and_return(query_result)

        payload
      end

      it "returns project task items" do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
          .and_return(query_result)

        expect(payload).to eq(snake_items)
      end
    end

    context "when the project name is URL-encoded" do
      let(:uri) { "omnifocus://project/Side%20Hustle" }
      let(:query_result) { ok_match([]) }

      it "passes the decoded project name to QueryOmnifocus" do
        expect(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call).with(
          an_object_having_attributes(
            entity: "tasks",
            filters: { project_name: "Side Hustle" },
            fields: described_class::FIELDS
          )
        ).and_return(query_result)

        payload
      end

      it "returns an empty array" do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
          .and_return(query_result)

        expect(payload).to eq([])
      end
    end

    context "when the URI omits a project name" do
      let(:uri) { "omnifocus://project/" }
      let(:query_result) { ok_match([]) }

      it "queries with an empty project_name" do
        expect(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call).with(
          an_object_having_attributes(
            entity: "tasks",
            filters: { project_name: "" },
            fields: described_class::FIELDS
          )
        ).and_return(query_result)

        payload
      end

      it "returns an empty array" do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
          .and_return(query_result)

        expect(payload).to eq([])
      end
    end

    context "when the query succeeds with nil items" do
      let(:uri) { "omnifocus://project/Errands" }

      it "returns an empty array" do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
          .and_return(OmnifocusMcp::Result.ok(match.new(items: nil, count: 0)))

        expect(payload).to eq([])
      end
    end

    context "when the query succeeds with an empty array" do
      let(:uri) { "omnifocus://project/Errands" }

      it "returns an empty array" do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
          .and_return(ok_match([]))

        expect(payload).to eq([])
      end
    end

    context "when the query fails" do
      let(:uri) { "omnifocus://project/Whatever" }

      before do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
          .and_return(OmnifocusMcp::Result.error("no such project"))
      end

      it "returns an error envelope hash" do
        expect(payload).to eq({ error: "no such project" })
      end
    end
  end

  describe "#content" do
    subject(:content) { resource.content }

    let(:resource) { described_class.initialize_from_uri(uri) }

    before { allow(OmnifocusMcp).to receive(:logger).and_return(instance_double(Logger, warn: nil)) }

    context "when the project resolves" do
      let(:uri) { "omnifocus://project/Errands" }

      it "pretty-prints the payload as JSON" do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
          .and_return(ok_match(items))

        expect(content).to eq(JSON.pretty_generate(items))
      end
    end

    context "when the query fails" do
      let(:uri) { "omnifocus://project/Whatever" }

      it "pretty-prints the error envelope as JSON" do
        allow(OmnifocusMcp::Tools::Operations::QueryOmnifocus).to receive(:call)
          .and_return(OmnifocusMcp::Result.error("no such project"))

        expect(content).to eq(JSON.pretty_generate(error: "no such project"))
      end
    end
  end
end
