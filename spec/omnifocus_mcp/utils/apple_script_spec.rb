# frozen_string_literal: true

require "omnifocus_mcp/utils/apple_script"

# Core AppleScript DSL: indent, escape, tell_document, find_item, tag_assignment.
RSpec.describe OmnifocusMcp::Utils::AppleScript do
  describe ".indent" do
    it "prefixes every non-empty line with the given prefix" do
      input = "alpha\nbeta\ngamma\n"
      expect(described_class.indent(text: input, prefix: "  ")).to eq("  alpha\n  beta\n  gamma\n")
    end

    it "leaves blank lines untouched so prefix never trails whitespace" do
      input = "alpha\n\nbeta\n"
      expect(described_class.indent(text: input, prefix: ">> ")).to eq(">> alpha\n\n>> beta\n")
    end

    it "leaves whitespace-only lines untouched" do
      input = "alpha\n   \nbeta\n"
      expect(described_class.indent(text: input, prefix: ">> ")).to eq(">> alpha\n   \n>> beta\n")
    end

    it "preserves the absence of a trailing newline" do
      expect(described_class.indent(text: "one\ntwo", prefix: "  ")).to eq("  one\n  two")
    end
  end

  describe ".escape" do
    it "escapes embedded double quotes" do
      expect(described_class.escape('say "hi"')).to eq('say \"hi\"')
    end

    it "escapes embedded backslashes" do
      expect(described_class.escape("path\\to")).to eq("path\\\\to")
    end

    it "collapses CR and LF to a single space" do
      expect(described_class.escape("one\nline\rbreak")).to eq("one line break")
    end

    it "coerces non-strings via to_s" do
      expect(described_class.escape(42)).to eq("42")
    end

    it "escapes quotes, backslashes, and newlines together" do
      expect(described_class.escape(%(say "hi"\npath\\to))).to eq('say \"hi\" path\\\\to')
    end
  end

  describe ".tell_document" do
    subject(:wrapped) { described_class.tell_document("set foo to 1\nset bar to 2") }

    it "opens the OmniFocus application tell block" do
      expect(wrapped).to include(%(tell application "OmniFocus"))
    end

    it "opens the front document tell block" do
      expect(wrapped).to include("tell front document")
    end

    it "closes both tell blocks" do
      expect(wrapped).to include("end tell\n  end tell\n")
    end

    it "indents the first body line" do
      expect(wrapped).to include("      set foo to 1")
    end

    it "indents the second body line" do
      expect(wrapped).to include("      set bar to 2")
    end

    it "handles errors via on error" do
      expect(wrapped).to include("on error errorMessage")
    end

    it "returns a JSON error envelope on failure" do
      expect(wrapped).to include(%(return "{\\"success\\":false,\\"error\\":\\"" & errorMessage & "\\"}"))
    end

    context "with an empty body" do
      subject(:wrapped) { described_class.tell_document("") }

      it "opens the OmniFocus application tell block" do
        expect(wrapped).to include(%(tell application "OmniFocus"))
      end

      it "opens the front document tell block" do
        expect(wrapped).to include("tell front document")
      end

      it "handles errors via on error" do
        expect(wrapped).to include("on error errorMessage")
      end
    end
  end

  describe "ITEM_TYPES" do
    it "lists task and project" do
      expect(described_class::ITEM_TYPES).to eq(%w[task project])
    end

    it "is frozen" do
      expect(described_class::ITEM_TYPES).to be_frozen
    end
  end

  describe ".find_item" do
    context "with an unknown item_type" do
      it "raises ArgumentError" do
        expect do
          described_class.find_item(var: "x", item_type: "taks", id: "abc", name: "")
        end.to raise_error(ArgumentError, /item_type must be one of/)
      end
    end

    context "with id only" do
      subject(:script) { described_class.find_item(var: "foundItem", item_type: "task", id: "abc123", name: "") }

      it "initialises the variable to missing value" do
        expect(script).to include("set foundItem to missing value")
      end

      it "searches by id" do
        expect(script).to include(%(first flattened task whose id is "abc123"))
      end

      it "does not include a name search branch" do
        expect(script).not_to include("whose name is")
      end

      it "includes the id search comment" do
        expect(script).to include("-- Find task by ID")
      end
    end

    context "with name only" do
      subject(:script) { described_class.find_item(var: "foundItem", item_type: "task", id: "", name: "My Task") }

      it "searches by name" do
        expect(script).to include(%(first flattened task whose name is "My Task"))
      end

      it "does not include an id search branch" do
        expect(script).not_to include("whose id is")
      end

      it "includes the name search comment" do
        expect(script).to include("-- Find task by name")
      end
    end

    context "with both id and name" do
      subject(:script) { described_class.find_item(var: "foundItem", item_type: "task", id: "abc", name: "fallback") }

      it "searches by id first" do
        expect(script).to include(%(first flattened task whose id is "abc"))
      end

      it "guards the name fallback with a missing-value check" do
        expect(script).to include("if foundItem is missing value then")
      end

      it "searches by name when the id misses" do
        expect(script).to include(%(first flattened task whose name is "fallback"))
      end

      it "includes the fallback comment" do
        expect(script).to include("-- Fall back to name search if id missed")
      end
    end

    context "with item_type project" do
      context "with id only" do
        subject(:script) { described_class.find_item(var: "p", item_type: "project", id: "p1", name: "") }

        it "searches in flattened projects" do
          expect(script).to include(%(first flattened project whose id is "p1"))
        end
      end

      context "with name only" do
        subject(:script) { described_class.find_item(var: "p", item_type: "project", id: "", name: "My Project") }

        it "searches by name" do
          expect(script).to include(%(first flattened project whose name is "My Project"))
        end

        it "does not include an id search branch" do
          expect(script).not_to include("whose id is")
        end

        it "includes the name search comment" do
          expect(script).to include("-- Find project by name")
        end
      end
    end

    context "with a custom variable name" do
      subject(:script) { described_class.find_item(var: "myItem", item_type: "task", id: "x", name: "") }

      it "initialises the custom variable to missing value" do
        expect(script).to include("set myItem to missing value")
      end

      it "assigns the found item to the custom variable" do
        expect(script).to include("set myItem to first flattened task")
      end
    end
  end

  describe ".tag_assignment" do
    subject(:script) { described_class.tag_assignment(item_var: "newTask", tag_name: "urgent") }

    it "looks up the tag by name" do
      expect(script).to include(%(first flattened tag where name = "urgent"))
    end

    it "adds the tag to the item" do
      expect(script).to include("add theTag to tags of newTask")
    end

    it "creates the tag on lookup failure" do
      expect(script).to include(%(make new tag with properties {name:"urgent"}))
    end

    it "swallows the inner add error so a partial failure does not abort" do
      expect(script).to include("-- Could not create or add tag")
    end

    context "with a custom item variable" do
      subject(:script) { described_class.tag_assignment(item_var: "editedTask", tag_name: "work") }

      it "adds the tag to the custom item variable" do
        expect(script).to include("add theTag to tags of editedTask")
      end
    end
  end
end
