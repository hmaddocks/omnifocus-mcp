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

  describe ".multiline_string" do
    it "keeps line feeds as AppleScript escapes" do
      expect(described_class.multiline_string("a\nb")).to eq('a\nb')
    end

    it "normalises CRLF and CR to one line feed" do
      expect(described_class.multiline_string("a\r\nb\rc")).to eq('a\nb\nc')
    end

    it "escapes AppleScript string delimiters" do
      expect(described_class.multiline_string('say "hi"')).to eq('say \"hi\"')
    end
  end

  describe ".tag_lookup" do
    subject(:script) { described_class.tag_lookup(var: "t", tag_path: tag_path, create: create) }

    let(:tag_path) { "Gidoca triage/ready-for-agent" }
    let(:create) { true }

    it "finds the first part anywhere" do
      expect(script).to include(%(set t to first flattened tag whose name is "Gidoca triage"))
    end

    it "finds later parts inside the previous tag" do
      expect(script).to include(%(set t to first tag of tParent whose name is "ready-for-agent"))
    end

    it "creates missing parts inside the previous tag" do
      expect(script).to include(%(make new tag with properties {name:"ready-for-agent"} at end of tags of tParent))
    end

    it "escapes each part" do
      expect(described_class.tag_lookup(var: "t", tag_path: 'Say "hi"', create: true))
        .to include(%(whose name is "Say \\"hi\\""))
    end

    context "without create" do
      let(:create) { false }

      it "never makes a tag" do
        expect(script).not_to include("make new tag")
      end
    end

    context "with a bare tag name" do
      let(:tag_path) { "Mac" }

      it "does not walk into child tags" do
        expect(script).not_to include("first tag of")
      end
    end

    context "with a name containing a slash" do
      let(:tag_path) { "a/b" }

      it "treats it as a path" do
        expect(script).to include(%(first tag of tParent whose name is "b"))
      end
    end

    context "with empty path parts" do
      let(:tag_path) { "/Mac/" }

      it "ignores them" do
        expect(script).not_to include("first tag of")
      end
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

    it "defines the jsonEscape handler" do
      expect(script).to include("on jsonEscape(theText)")
    end

    it "escapes the error message in the failure reply" do
      expect(script).to include("my jsonEscape(errorMessage)")
    end
  end

  describe ".json_escape_handler" do
    subject(:handler) { described_class.json_escape_handler }

    it "escapes backslashes before quotes" do
      expect(handler.index('{"\\\\", "\\\\\\\\"}')).to be < handler.index('{"\\"", "\\\\\\""}')
    end

    it "escapes line breaks" do
      expect(handler).to include('{linefeed, "\\\\n"}')
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
