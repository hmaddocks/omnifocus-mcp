# frozen_string_literal: true

require "omnifocus_mcp/utils/apple_script_helpers"

RSpec.describe OmnifocusMcp::Utils::AppleScriptHelpers do
  describe "LOOKUP_KINDS" do
    it "lists folder and project" do
      expect(described_class::LOOKUP_KINDS).to eq(%i[folder project])
    end

    it "is frozen" do
      expect(described_class::LOOKUP_KINDS).to be_frozen
    end
  end

  describe ".generate_lookup_script" do
    context "when kind is folder" do
      subject(:script) do
        described_class.generate_lookup_script(
          kind: :folder, raw_path: "Work", var_name: "f", error_return_json: "err"
        )
      end

      it "delegates to the folder pipeline" do
        expect(script).to include(%(first flattened folder where name = "Work"))
      end
    end

    context "when kind is project" do
      subject(:script) do
        described_class.generate_lookup_script(
          kind: :project, raw_path: "Marketing", var_name: "p", error_return_json: "err"
        )
      end

      it "delegates to the project pipeline" do
        expect(script).to include(%(first flattened project whose name is "Marketing"))
      end
    end

    context "when kind is unknown" do
      it "raises ArgumentError" do
        expect do
          described_class.generate_lookup_script(
            kind: :widget, raw_path: "Foo", var_name: "v", error_return_json: "err"
          )
        end.to raise_error(ArgumentError, /kind must be one of/)
      end
    end

    context "with an empty path" do
      subject(:script) do
        described_class.generate_lookup_script(
          kind: :folder, raw_path: "", var_name: "v", error_return_json: "err"
        )
      end

      it "returns only the missing-value assignment" do
        expect(script).to eq("set v to missing value")
      end

      it "does not attempt a lookup" do
        expect(script).not_to include("flattened")
      end
    end

    context "with a slash-only path" do
      subject(:script) do
        described_class.generate_lookup_script(
          kind: :project, raw_path: "//", var_name: "p", error_return_json: "err"
        )
      end

      it "returns only the missing-value assignment" do
        expect(script).to eq("set p to missing value")
      end
    end

    context "with empty path segments between slashes" do
      subject(:script) do
        described_class.generate_lookup_script(
          kind: :folder, raw_path: "A//B", var_name: "f", error_return_json: "err"
        )
      end

      it "treats the path as two segments" do
        expect(script).to include(%("A", "B"))
      end

      it "uses nested folder lookup" do
        expect(script).to include("pathComponents")
      end
    end
  end

  describe ".generate_folder_lookup_script" do
    context "with a single-component path" do
      subject(:script) do
        described_class.generate_folder_lookup_script(raw_folder_path: "Work", var_name: "destFolder",
                                                      error_return_json: "error")
      end

      it "uses a flat folder search" do
        expect(script).to include(%(first flattened folder where name = "Work"))
      end

      it "does not use pathComponents for walking" do
        expect(script).not_to include("pathComponents")
      end

      it "does not use ancestorOk for walking" do
        expect(script).not_to include("ancestorOk")
      end
    end

    context "with a two-segment path" do
      subject(:script) do
        described_class.generate_folder_lookup_script(raw_folder_path: "Work/Engineering", var_name: "destFolder",
                                                      error_return_json: "error")
      end

      it "includes the first path segment" do
        expect(script).to include(%("Work"))
      end

      it "includes the second path segment" do
        expect(script).to include(%("Engineering"))
      end

      it "uses pathComponents for walking" do
        expect(script).to include("pathComponents")
      end

      it "uses ancestorOk for walking" do
        expect(script).to include("ancestorOk")
      end

      it "checks the leaf folder name" do
        expect(script).to include(%(name of aFolder = "Engineering"))
      end

      it "traverses the container chain" do
        expect(script).to include("container of currentItem")
      end
    end

    context "with a three-segment path" do
      subject(:script) do
        described_class.generate_folder_lookup_script(raw_folder_path: "A/B/C", var_name: "theFolder",
                                                      error_return_json: "error")
      end

      it "lists all path segments" do
        expect(script).to include(%("A", "B", "C"))
      end

      it "checks the leaf folder name" do
        expect(script).to include(%(name of aFolder = "C"))
      end

      it "uses path component walking" do
        expect(script).to include("pathComponents")
      end
    end

    context "with special characters in folder names" do
      context "when the name contains double quotes" do
        subject(:script) do
          described_class.generate_folder_lookup_script(raw_folder_path: 'My "Folder"', var_name: "f",
                                                        error_return_json: "error")
        end

        it "escapes double quotes" do
          expect(script).to include('My \"Folder\"')
        end
      end

      context "when the name contains backslashes" do
        subject(:script) do
          described_class.generate_folder_lookup_script(raw_folder_path: "Back\\slash", var_name: "f",
                                                        error_return_json: "error")
        end

        it "escapes backslashes" do
          expect(script).to include("Back\\\\slash")
        end
      end
    end

    context "with special characters in path segments" do
      subject(:script) do
        described_class.generate_folder_lookup_script(raw_folder_path: 'Parent/Child "Folder"', var_name: "f",
                                                      error_return_json: "error")
      end

      it "escapes double quotes in the leaf segment" do
        expect(script).to include('Child \"Folder\"')
      end

      it "includes the parent segment" do
        expect(script).to include(%("Parent"))
      end
    end

    context "with an empty path" do
      subject(:script) do
        described_class.generate_folder_lookup_script(raw_folder_path: "", var_name: "f", error_return_json: "error")
      end

      it "sets the variable to missing value" do
        expect(script).to include("set f to missing value")
      end

      it "does not attempt a folder lookup" do
        expect(script).not_to include("flattened folder")
      end
    end

    context "with a slash-only path" do
      subject(:script) do
        described_class.generate_folder_lookup_script(raw_folder_path: "/", var_name: "f", error_return_json: "error")
      end

      it "sets the variable to missing value" do
        expect(script).to include("set f to missing value")
      end
    end

    context "with a whitespace-only path" do
      subject(:script) do
        described_class.generate_folder_lookup_script(raw_folder_path: "   ", var_name: "f", error_return_json: "error")
      end

      it "uses a flat folder search for the whitespace segment" do
        expect(script).to include(%(first flattened folder where name = "   "))
      end
    end

    context "with empty segments between slashes" do
      subject(:script) do
        described_class.generate_folder_lookup_script(
          raw_folder_path: "A//B", var_name: "f", error_return_json: "error"
        )
      end

      it "collapses to a two-segment path" do
        expect(script).to include(%("A", "B"))
      end
    end

    context "with a newline in a path segment" do
      subject(:script) do
        described_class.generate_folder_lookup_script(raw_folder_path: "A\nB/C", var_name: "f",
                                                      error_return_json: "error")
      end

      it "collapses the newline to a space in the first segment" do
        expect(script).to include(%("A B", "C"))
      end
    end

    context "with a trailing slash" do
      subject(:script) do
        described_class.generate_folder_lookup_script(raw_folder_path: "Work/", var_name: "f",
                                                      error_return_json: "error")
      end

      it "uses a flat folder search after stripping the empty segment" do
        expect(script).to include(%(first flattened folder where name = "Work"))
      end

      it "does not use path component walking" do
        expect(script).not_to include("pathComponents")
      end
    end

    context "with a custom variable name" do
      subject(:script) do
        described_class.generate_folder_lookup_script(raw_folder_path: "Work", var_name: "myVar",
                                                      error_return_json: "error")
      end

      it "initialises the variable to missing value" do
        expect(script).to include("set myVar to missing value")
      end

      it "assigns the found folder to the variable" do
        expect(script).to include("set myVar to first flattened folder")
      end

      it "checks the variable in the not-found guard" do
        expect(script).to include("if myVar is missing value")
      end
    end

    context "with a custom error return value" do
      let(:error_json) { '{\"success\":false}' }

      context "with a single-segment path" do
        subject(:script) do
          described_class.generate_folder_lookup_script(raw_folder_path: "Work", var_name: "f",
                                                        error_return_json: error_json)
        end

        it "embeds the error JSON" do
          expect(script).to include(%(return "#{error_json}"))
        end
      end

      context "with a multi-segment path" do
        subject(:script) do
          described_class.generate_folder_lookup_script(raw_folder_path: "A/B", var_name: "f",
                                                        error_return_json: error_json)
        end

        it "embeds the error JSON" do
          expect(script).to include(%(return "#{error_json}"))
        end
      end
    end

    context "with a multi-segment path and a missing-value guard" do
      subject(:script) do
        described_class.generate_folder_lookup_script(raw_folder_path: "A/B", var_name: "f",
                                                      error_return_json: "not-found-error")
      end

      it "checks for missing value" do
        expect(script).to include("if f is missing value")
      end

      it "returns the error string on not found" do
        expect(script).to include(%(return "not-found-error"))
      end
    end
  end

  describe ".generate_project_lookup_script" do
    context "with an unqualified project name" do
      subject(:script) do
        described_class.generate_project_lookup_script(raw_project_path: "Marketing", var_name: "destProject",
                                                       error_return_json: "error")
      end

      it "uses a flat project search" do
        expect(script).to include(%(first flattened project whose name is "Marketing"))
      end

      it "does not use folder path walking" do
        expect(script).not_to include("folderPath")
      end
    end

    context "with a folder-qualified path" do
      subject(:script) do
        described_class.generate_project_lookup_script(raw_project_path: "Work/Community Outreach",
                                                       var_name: "destProject",
                                                       error_return_json: "error")
      end

      it "includes the project name" do
        expect(script).to include(%("Community Outreach"))
      end

      it "uses folder path walking" do
        expect(script).to include("folderPath")
      end

      it "includes the folder segment" do
        expect(script).to include(%("Work"))
      end

      it "traverses the project container" do
        expect(script).to include("container of aProject")
      end

      it "uses ancestor checking" do
        expect(script).to include("ancestorOk")
      end
    end

    context "with a nested folder path" do
      subject(:script) do
        described_class.generate_project_lookup_script(raw_project_path: "Personal/Committees/Outreach", var_name: "p",
                                                       error_return_json: "error")
      end

      it "lists the folder path segments" do
        expect(script).to include(%("Personal", "Committees"))
      end

      it "includes the project name" do
        expect(script).to include(%("Outreach"))
      end

      it "uses folder path walking" do
        expect(script).to include("folderPath")
      end
    end

    context "with an empty path" do
      subject(:script) do
        described_class.generate_project_lookup_script(raw_project_path: "", var_name: "p", error_return_json: "error")
      end

      it "sets the variable to missing value" do
        expect(script).to include("set p to missing value")
      end

      it "does not attempt a project lookup" do
        expect(script).not_to include("flattened projects")
      end
    end

    context "with special characters in the project name" do
      subject(:script) do
        described_class.generate_project_lookup_script(raw_project_path: 'My "Project"', var_name: "p",
                                                       error_return_json: "error")
      end

      it "escapes double quotes" do
        expect(script).to include('My \"Project\"')
      end
    end

    context "with a custom variable name" do
      subject(:script) do
        described_class.generate_project_lookup_script(raw_project_path: "Test", var_name: "myProj",
                                                       error_return_json: "error")
      end

      it "initialises the variable to missing value" do
        expect(script).to include("set myProj to missing value")
      end

      it "assigns the found project to the variable" do
        expect(script).to include(%(set myProj to first flattened project whose name is "Test"))
      end

      it "checks the variable in the not-found guard" do
        expect(script).to include("if myProj is missing value")
      end
    end

    context "with a custom error return value" do
      subject(:script) do
        described_class.generate_project_lookup_script(raw_project_path: "Test", var_name: "p",
                                                       error_return_json: error_json)
      end

      let(:error_json) { '{\"success\":false}' }

      it "embeds the error JSON in the return statement" do
        expect(script).to include(%(return "#{error_json}"))
      end
    end
  end
end
