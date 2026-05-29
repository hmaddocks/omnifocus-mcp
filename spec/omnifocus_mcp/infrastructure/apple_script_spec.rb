# frozen_string_literal: true

require "omnifocus_mcp/infrastructure/apple_script"
require "omnifocus_mcp/utils/apple_script"
require "omnifocus_mcp/utils/apple_script_helpers"

RSpec.describe OmnifocusMcp::Infrastructure::AppleScript do
  describe ".escape" do
    it "escapes AppleScript string delimiters" do
      expect(described_class.escape('say "hi"')).to eq('say \"hi\"')
    end

    it "collapses line breaks to spaces" do
      expect(described_class.escape("one\nline\rbreak")).to eq("one line break")
    end
  end

  describe ".tell_document" do
    subject(:script) { described_class.tell_document("set foo to 1") }

    it "wraps the body in an OmniFocus front document tell block" do
      expect(script).to include(%(tell application "OmniFocus"))
    end

    it "indents the supplied body" do
      expect(script).to include("      set foo to 1")
    end
  end

  describe ".find_item" do
    subject(:script) { described_class.find_item(var: "foundItem", item_type: "task", id: "abc", name: "fallback") }

    it "searches by id first" do
      expect(script).to include(%(first flattened task whose id is "abc"))
    end

    it "guards the fallback name lookup" do
      expect(script).to include("if foundItem is missing value then")
    end
  end

  describe ".generate_folder_lookup_script" do
    subject(:script) do
      described_class.generate_folder_lookup_script(
        raw_folder_path: "Work/Engineering",
        var_name: "destFolder",
        error_return_json: "error"
      )
    end

    it "uses path component walking" do
      expect(script).to include("pathComponents")
    end

    it "checks the leaf folder name" do
      expect(script).to include(%(name of aFolder = "Engineering"))
    end
  end

  describe ".generate_project_lookup_script" do
    subject(:script) do
      described_class.generate_project_lookup_script(
        raw_project_path: "Work/Community Outreach",
        var_name: "destProject",
        error_return_json: "error"
      )
    end

    it "uses folder path walking" do
      expect(script).to include("folderPath")
    end

    it "checks the project name" do
      expect(script).to include(%("Community Outreach"))
    end
  end
end

RSpec.describe OmnifocusMcp::Utils::AppleScript do
  it "is a deprecated alias for Infrastructure::AppleScript" do
    expect(described_class).to equal(OmnifocusMcp::Infrastructure::AppleScript)
  end
end

RSpec.describe OmnifocusMcp::Utils::AppleScriptHelpers do
  it "is a deprecated alias for Infrastructure::AppleScript" do
    expect(described_class).to equal(OmnifocusMcp::Infrastructure::AppleScript)
  end
end
