# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/add_project"

RSpec.describe OmnifocusMcp::Tools::Generators::AddProject do
  describe ".generate_apple_script" do
    subject(:script) { described_class.generate_apple_script(name: "Test Project", folder_name: "Work") }

    it "creates the project" do
      expect(script).to include(%(make new project with properties {name:"Test Project"}))
    end

    it "escapes the project name in the reply" do
      expect(script).to include("my jsonEscape(name of newProject)")
    end

    it "looks up the destination folder" do
      expect(script).to include(%(first flattened folder where name = "Work"))
    end

    context "with a nested tag" do
      subject(:script) { described_class.generate_apple_script(name: "Test Project", tags: ["Work/Mac"]) }

      it "looks the child up inside its parent" do
        expect(script).to include(%(first tag of theTagParent whose name is "Mac"))
      end
    end

    context "with a multi-line note" do
      subject(:script) { described_class.generate_apple_script(name: "Test Project", note: "one\ntwo") }

      it "keeps the line break" do
        expect(script).to include('set note of newProject to "one\ntwo"')
      end
    end
  end
end
