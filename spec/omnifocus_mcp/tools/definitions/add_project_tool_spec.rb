# frozen_string_literal: true

require "omnifocus_mcp/tools/definitions/add_project_tool"

RSpec.describe OmnifocusMcp::Tools::Definitions::AddProjectTool do
  let(:created) { OmnifocusMcp::Tools::Operations::AddProject::Created }
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

  def ok_project(project_id = "P1")
    OmnifocusMcp::Result.ok(created.new(project_id: project_id))
  end

  describe ".tool_name and .description" do
    it "registers with the expected tool name" do
      expect(described_class.tool_name).to eq("add_project")
    end

    it "registers with the expected tool description" do
      expect(described_class.description).to eq("Add a new project to OmniFocus")
    end
  end

  describe ".input_schema_to_json" do
    subject(:schema) { described_class.input_schema_to_json }

    it "exposes camelCase property names in the MCP schema" do
      expect(schema[:properties].keys).to include(
        :name, :note, :dueDate, :deferDate, :flagged,
        :estimatedMinutes, :tags, :folderName, :sequential
      )
    end

    it "requires name" do
      expect(schema[:required]).to eq(["name"])
    end
  end

  describe "#call" do
    context "when creating a project at root" do
      subject(:envelope) { tool.call(name: "Launch") }

      before { stub_operation(ok_project) }

      it "returns a parallel success message" do
        expect(envelope[:content].first[:text])
          .to eq("\u2705 Project \"Launch\" created successfully at the root level (parallel).")
      end

      it "does not mark the envelope as an error" do
        expect(envelope[:isError]).to be_nil
      end
    end

    context "when creating a project in a folder without other annotations" do
      subject(:envelope) { tool.call(name: "Launch", folderName: "Work") }

      before { stub_operation(ok_project) }

      it "names the folder and defaults to parallel" do
        expect(envelope[:content].first[:text])
          .to eq("\u2705 Project \"Launch\" created successfully in folder \"Work\" (parallel).")
      end
    end

    context "when creating a sequential project in a folder with tags and a due date" do
      subject(:envelope) do
        tool.call(
          name: "Launch", folderName: "Work", tags: %w[client urgent],
          dueDate: "2026-05-23", sequential: true
        )
      end

      before { stub_operation(ok_project) }

      it "renders folder, due date, tags, and sequential annotations" do
        expect(envelope[:content].first[:text]).to eq(
          "\u2705 Project \"Launch\" created successfully in folder \"Work\" " \
          "due on 5/23/2026 with tags: client, urgent (sequential)."
        )
      end
    end

    context "with an empty tags array" do
      subject(:envelope) { tool.call(name: "Launch", tags: []) }

      before { stub_operation(ok_project) }

      it "omits tag text from the success message" do
        expect(envelope[:content].first[:text]).not_to include(" with tags:")
      end
    end

    context "when the operation fails" do
      subject(:envelope) { tool.call(name: "x") }

      before { stub_operation(OmnifocusMcp::Result.error("folder gone")) }

      it "marks the envelope as an error" do
        expect(envelope[:isError]).to be true
      end

      it "includes the operation's error message" do
        expect(envelope[:content].first[:text]).to eq("Failed to create project: folder gone")
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

        expect(envelope[:content].first[:text]).to eq("Error creating project: boom")
      end

      it "warns with the exception details on stderr" do
        expect { tool.call(name: "x") }.to output(/Error creating project: boom/).to_stderr
      end
    end
  end
end
