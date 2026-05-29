# frozen_string_literal: true

require "omnifocus_mcp/resources/base"

RSpec.describe OmnifocusMcp::Resources::Base do
  subject(:resource) { test_resource_class.new }

  let(:match) { OmnifocusMcp::Tools::Operations::QueryOmnifocus::Match }

  let(:test_resource_class) do
    Class.new(described_class) do
      uri "omnifocus://test"
      resource_name "test"
    end
  end

  let(:test_resource_with_payload_class) do
    Class.new(described_class) do
      uri "omnifocus://test"
      resource_name "test"
      define_method(:payload) do
        {
          due_today: [
            { id: "1", due_date: "2026-05-23", tag_names: ["Home"] }
          ],
          nested_value: { project_name: "Inbox" }
        }
      end
    end
  end

  let(:test_resource_with_nil_payload_class) do
    Class.new(described_class) do
      uri "omnifocus://test"
      resource_name "test"
      define_method(:payload) { nil }
    end
  end

  context "when metadata is defaulted" do
    it "defaults to application/json mime type" do
      expect(described_class.mime_type).to eq("application/json")
    end

    it "lets subclasses declare a URI" do
      expect(test_resource_class.uri).to eq("omnifocus://test")
    end

    it "lets subclasses declare a resource name" do
      expect(test_resource_class.resource_name).to eq("test")
    end
  end

  describe "#payload" do
    it "raises NotImplementedError when not overridden" do
      expect { resource.payload }.to raise_error(NotImplementedError, /must implement #payload/)
    end
  end

  describe "#content" do
    context "when payload is implemented" do
      subject(:content) { test_resource_with_payload_class.new.content }

      it "pretty-prints the payload as JSON with camelCase keys" do
        expect(content).to eq(
          JSON.pretty_generate(
            dueToday: [
              { id: "1", dueDate: "2026-05-23", tagNames: ["Home"] }
            ],
            nestedValue: { projectName: "Inbox" }
          )
        )
      end
    end

    context "when payload is not overridden" do
      it "returns an error payload instead of raising" do
        parsed = JSON.parse(resource.content)

        expect(parsed["error"]).to include("must implement #payload")
      end

      it "still raises NotImplementedError when payload is called directly" do
        expect { resource.payload }.to raise_error(NotImplementedError, /must implement #payload/)
      end
    end
  end

  describe "#items_or_empty" do
    subject(:items) { resource_with_nil_payload.items_or_empty(result) }

    let(:resource_with_nil_payload) { test_resource_with_nil_payload_class.new }

    context "when the query succeeds" do
      let(:result) { OmnifocusMcp::Result.ok(match.new(items: task_items, count: task_items.to_a.length)) }

      context "with task items" do
        let(:task_items) { [{ "name" => "a", "dueDate" => "2026-05-23" }] }

        it "returns items from the match" do
          expect(items).to eq([{ name: "a", due_date: "2026-05-23" }])
        end
      end

      context "when items is nil" do
        let(:task_items) { nil }

        it "returns an empty array" do
          expect(items).to eq([])
        end
      end

      context "when items is an empty array" do
        let(:task_items) { [] }

        it "returns an empty array" do
          expect(items).to eq([])
        end
      end
    end

    context "when the query fails" do
      let(:result) { OmnifocusMcp::Result.error("boom") }

      it "returns [] without surfacing the error" do
        expect(items).to eq([])
      end

      it "does not embed query errors in JSON content when used as payload data" do
        task_items = items

        payload_resource = Class.new(described_class) do
          uri "omnifocus://test"
          resource_name "test"
          define_method(:payload) { task_items }
        end

        expect(payload_resource.new.content).to eq(JSON.pretty_generate([]))
      end
    end
  end
end
