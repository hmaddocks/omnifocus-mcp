# frozen_string_literal: true

require "omnifocus_mcp/tools/definitions/add_omni_focus_task_tool"

RSpec.describe OmnifocusMcp::Tools::Definitions::AddOmniFocusTaskTool do
  let(:created) { OmnifocusMcp::Tools::Operations::AddOmniFocusTask::Created }
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

  def ok_inbox
    OmnifocusMcp::Result.ok(created.new(task_id: "T1", placement: "inbox"))
  end

  def ok_project
    OmnifocusMcp::Result.ok(created.new(task_id: "T1", placement: "project"))
  end

  def ok_parent
    OmnifocusMcp::Result.ok(created.new(task_id: "T1", placement: "parent"))
  end

  describe ".tool_name and .description" do
    it "registers with the expected tool name" do
      expect(described_class.tool_name).to eq("add_omnifocus_task")
    end

    it "registers with the expected tool description" do
      expect(described_class.description).to eq("Add a new task to OmniFocus")
    end
  end

  describe ".input_schema_to_json" do
    subject(:schema) { described_class.input_schema_to_json }

    it "exposes camelCase property names in the MCP schema" do
      expect(schema[:properties].keys).to include(
        :name, :note, :dueDate, :deferDate, :plannedDate,
        :flagged, :estimatedMinutes, :tags, :projectName,
        :parentTaskId, :parentTaskName, :hierarchyLevel
      )
    end

    it "requires name" do
      expect(schema[:required]).to eq(["name"])
    end
  end

  describe "#call" do
    context "when the task is created in the inbox" do
      subject(:envelope) { tool.call(name: "Buy milk") }

      before { stub_operation(ok_inbox) }

      it "returns a success envelope with inbox phrasing" do
        expect(envelope[:content].first[:text])
          .to start_with("\u2705 Task \"Buy milk\" created successfully in your inbox")
      end

      it "does not mark the envelope as an error" do
        expect(envelope[:isError]).to be_nil
      end
    end

    context "when the task is created in a project" do
      subject(:envelope) { tool.call(name: "Write tests", projectName: "Development") }

      before { stub_operation(ok_project) }

      it "names the project in the success message" do
        expect(envelope[:content].first[:text]).to include('in project "Development"')
      end
    end

    context "when the task is created in a project without a project name" do
      subject(:envelope) { tool.call(name: "Write tests") }

      before { stub_operation(ok_project) }

      it "uses generic project phrasing" do
        expect(envelope[:content].first[:text]).to include("in a project")
      end
    end

    context "when the task is created under a parent" do
      subject(:envelope) { tool.call(name: "Sub", parentTaskId: "P1") }

      before { stub_operation(ok_parent) }

      it "uses 'under the parent task' phrasing" do
        expect(envelope[:content].first[:text]).to include("under the parent task")
      end

      it "does not append a parent-not-found warning" do
        expect(envelope[:content].first[:text]).not_to include("Parent not found")
      end
    end

    context "when a parent was requested but the task landed in a project" do
      subject(:envelope) do
        tool.call(name: "Sub", parentTaskName: "Missing", projectName: "Dev")
      end

      before { stub_operation(ok_project) }

      it "appends a project placement warning" do
        expect(envelope[:content].first[:text])
          .to include("\u26A0\uFE0F Parent not found; task created in project.")
      end
    end

    context "when a parent was requested but the task landed in the inbox" do
      subject(:envelope) { tool.call(name: "Sub", parentTaskName: "Missing") }

      before { stub_operation(ok_inbox) }

      it "appends an inbox placement warning" do
        expect(envelope[:content].first[:text])
          .to include("\u26A0\uFE0F Parent not found; task created in inbox.")
      end
    end

    context "with tags and a due date" do
      subject(:envelope) do
        tool.call(name: "Read", tags: %w[home reading], dueDate: "2026-05-23")
      end

      before { stub_operation(ok_inbox) }

      let(:text) { envelope[:content].first[:text] }

      it "renders the due date in locale format" do
        expect(text).to include(" due on 5/23/2026")
      end

      it "renders the tag list" do
        expect(text).to include(" with tags: home, reading")
      end
    end

    context "with an empty tags array" do
      subject(:envelope) { tool.call(name: "Read", tags: []) }

      before { stub_operation(ok_inbox) }

      it "omits tag text from the success message" do
        expect(envelope[:content].first[:text]).not_to include(" with tags:")
      end
    end

    context "when the operation returns failure" do
      subject(:envelope) { tool.call(name: "x") }

      before { stub_operation(OmnifocusMcp::Result.error("no project")) }

      it "marks the envelope as an error" do
        expect(envelope[:isError]).to be true
      end

      it "includes the operation's error message" do
        expect(envelope[:content].first[:text]).to eq("Failed to create task: no project")
      end
    end

    context "when the operation raises" do
      before { described_class.operation_factory = -> { ->(_) { raise "boom" } } }

      it "marks the envelope as an error" do
        envelope = silence_stderr { tool.call(name: "x") }

        expect(envelope[:isError]).to be true
      end

      it "includes the safely-wrapped exception message" do
        envelope = silence_stderr { tool.call(name: "x") }

        expect(envelope[:content].first[:text]).to eq("Error creating task: boom")
      end

      it "warns with the exception details on stderr" do
        expect { tool.call(name: "x") }.to output(/Error creating task: boom/).to_stderr
      end
    end
  end
end
