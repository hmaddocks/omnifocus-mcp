# frozen_string_literal: true

require "omnifocus_mcp/tools/definitions/query_omnifocus_tool"

RSpec.describe OmnifocusMcp::Tools::Definitions::QueryOmnifocusTool do
  let(:match) { OmnifocusMcp::Tools::Operations::QueryOmnifocus::Match }
  let(:tool) { described_class.new }

  before { described_class.operation_factory = nil }
  after  { described_class.operation_factory = nil }

  def silence_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
  ensure
    $stderr = original
  end

  def stub_operation(result)
    captured = nil
    described_class.operation_factory = lambda do
      lambda do |params|
        captured = params
        result
      end
    end
    -> { captured }
  end

  describe ".tool_name and .description" do
    it "registers with the expected tool name" do
      expect(described_class.tool_name).to eq("query_omnifocus")
    end

    it "registers with the expected tool description" do
      expect(described_class.description).to start_with("Efficiently query OmniFocus database with powerful filters")
    end
  end

  describe ".input_schema_to_json" do
    subject(:schema) { described_class.input_schema_to_json }

    it "requires entity" do
      expect(schema[:required]).to eq(["entity"])
    end

    it "exposes filters, limit, sortBy, format, and summary as optional properties" do
      expect(schema[:properties].keys).to include(
        :entity, :filters, :fields, :limit, :sortBy, :sortOrder, :includeCompleted, :format, :summary
      )
    end
  end

  describe "#call" do
    context "with summary: true" do
      subject(:envelope) { tool.call(entity: "tasks", summary: true) }

      before { stub_operation(OmnifocusMcp::Result.ok(match.new(items: nil, count: 42))) }

      it "returns the count line and skips the formatter" do
        expect(envelope[:content].first[:text]).to eq("Found 42 tasks matching your criteria.")
      end

      it "does not mark the envelope as an error" do
        expect(envelope[:isError]).to be_nil
      end
    end

    context "without summary" do
      context "when formatting task results" do
        subject(:envelope) { tool.call(entity: "tasks") }

        before do
          stub_operation(
            OmnifocusMcp::Result.ok(match.new(count: 1, items: [
                                                { "id" => "T1", "name" => "Reply", "flagged" => true }
                                              ]))
          )
        end

        let(:text) { envelope[:content].first[:text] }

        it "renders the query results header" do
          expect(text).to start_with("## Query Results: 1 tasks")
        end

        it "formats each task line" do
          expect(text).to include("\u2022 \u{1F6A9} Reply [T1]")
        end
      end

      context "when filters are provided" do
        subject(:envelope) do
          tool.call(entity: "tasks", filters: { taskName: "email" })
        end

        before do
          stub_operation(
            OmnifocusMcp::Result.ok(match.new(count: 1, items: [
                                                { "id" => "T1", "name" => "Email" }
                                              ]))
          )
        end

        it "passes camelCase MCP filters to the formatter summary" do
          expect(envelope[:content].first[:text])
            .to include('Filters applied: task: "email"')
        end
      end

      context "when formatting project results" do
        subject(:envelope) { tool.call(entity: "projects") }

        before do
          stub_operation(
            OmnifocusMcp::Result.ok(match.new(count: 1, items: [
                                                { "name" => "Launch", "status" => "Active", "taskCount" => 2 }
                                              ]))
          )
        end

        it "formats project lines through the formatter" do
          expect(envelope[:content].first[:text]).to include("P: Launch (2 tasks)")
        end
      end

      context "when formatting folder results" do
        subject(:envelope) { tool.call(entity: "folders") }

        before do
          stub_operation(
            OmnifocusMcp::Result.ok(match.new(count: 1, items: [
                                                { "name" => "Work", "projectCount" => 2, "path" => "Top/Work" }
                                              ]))
          )
        end

        it "formats folder lines through the formatter" do
          expect(envelope[:content].first[:text]).to include("F: Work (2 projects) 📍 Top/Work")
        end
      end

      context "when the result count equals the limit" do
        subject(:envelope) { tool.call(entity: "tasks", limit: 2) }

        before do
          stub_operation(
            OmnifocusMcp::Result.ok(match.new(count: 2, items: [
                                                { "id" => "T1", "name" => "a" },
                                                { "id" => "T2", "name" => "b" }
                                              ]))
          )
        end

        it "appends the limit warning" do
          expect(envelope[:content].first[:text])
            .to include("\u26A0\uFE0F Results limited to 2 items.")
        end
      end

      context "when the result count is below the limit" do
        subject(:envelope) { tool.call(entity: "tasks", limit: 2) }

        before do
          stub_operation(
            OmnifocusMcp::Result.ok(match.new(count: 1, items: [
                                                { "id" => "T1", "name" => "Only one" }
                                              ]))
          )
        end

        it "does not append the limit warning" do
          expect(envelope[:content].first[:text]).not_to include("\u26A0\uFE0F Results limited")
        end
      end
    end

    context "with format: json" do
      subject(:payload) { JSON.parse(envelope[:content].first[:text]) }

      let(:envelope) { tool.call(entity: "tasks", filters: { projectName: "Errands" }, format: "json", limit: 2) }

      before do
        stub_operation(
          OmnifocusMcp::Result.ok(match.new(count: 1, items: [
                                              {
                                                "id" => "T1",
                                                "name" => "Buy milk",
                                                "projectName" => "Errands"
                                              }
                                            ]))
        )
      end

      it "returns structured query metadata" do
        expect(payload).to include(
          "entity" => "tasks",
          "count" => 1,
          "filters" => { "projectName" => "Errands" },
          "limit" => 2
        )
      end

      it "returns the raw query items as JSON" do
        expect(payload["items"]).to eq([
                                         {
                                           "id" => "T1",
                                           "name" => "Buy milk",
                                           "projectName" => "Errands"
                                         }
                                       ])
      end

      it "does not mark the envelope as an error" do
        expect(envelope[:isError]).to be_nil
      end
    end

    context "with named date filters" do
      subject(:params) { get_captured.call }

      before do
        get_captured
        tool.call(entity: "tasks", filters: { dueWithin: "today", deferOn: "tomorrow" })
      end

      let(:get_captured) { stub_operation(OmnifocusMcp::Result.ok(match.new(count: 0, items: []))) }

      it "resolves date filters to numeric due_within" do
        expect(params.filters[:due_within]).to eq(0)
      end

      it "resolves date filters to numeric defer_on" do
        expect(params.filters[:defer_on]).to eq(1)
      end
    end

    context "with the remaining named date filter fields" do
      subject(:params) { get_captured.call }

      before do
        get_captured
        tool.call(
          entity: "tasks",
          filters: {
            deferredUntil: "today",
            plannedWithin: "tomorrow",
            dueOn: "today",
            plannedOn: "tomorrow"
          }
        )
      end

      let(:get_captured) { stub_operation(OmnifocusMcp::Result.ok(match.new(count: 0, items: []))) }

      it "resolves every DATE_FILTER_FIELD to numeric days-from-now" do
        expect(params.filters).to include(
          deferred_until: 0,
          planned_within: 1,
          due_on: 0,
          planned_on: 1
        )
      end
    end

    context "when the operation fails" do
      subject(:envelope) { tool.call(entity: "tasks") }

      before { stub_operation(OmnifocusMcp::Result.error("kaboom")) }

      it "marks the envelope as an error" do
        expect(envelope[:isError]).to be true
      end

      it "includes the operation error message" do
        expect(envelope[:content].first[:text]).to eq("Query failed: kaboom")
      end
    end

    context "when the operation raises" do
      before { described_class.operation_factory = -> { ->(_) { raise "boom" } } }

      it "marks the envelope as an error" do
        envelope = silence_stderr { tool.call(entity: "tasks") }

        expect(envelope[:isError]).to be true
      end

      it "wraps unexpected exceptions" do
        envelope = silence_stderr { tool.call(entity: "tasks") }

        expect(envelope[:content].first[:text]).to eq("Error executing query: boom")
      end

      it "warns with the exception details on stderr" do
        expect { tool.call(entity: "tasks") }.to output(/Error executing query: boom/).to_stderr
      end
    end
  end
end
