# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/edit_item"

RSpec.describe OmnifocusMcp::Tools::Generators::EditItem do
  describe ".generate_apple_script" do
    subject(:script) { described_class.generate_apple_script(item_type: "task", name: "Task", new_name: "Updated") }

    it "updates the requested property" do
      expect(script).to include(%(set name of foundItem to "Updated"))
    end

    it "escapes the item name in the reply" do
      expect(script).to include("my jsonEscape(itemName)")
    end

    context "with a multi-line note" do
      subject(:script) do
        described_class.generate_apple_script(item_type: "task", id: "abc", new_note: "Status: open\nBody")
      end

      it "keeps the line break" do
        expect(script).to include('set note of foundItem to "Status: open\nBody"')
      end
    end

    context "when adding a nested tag" do
      subject(:script) do
        described_class.generate_apple_script(item_type: "task", id: "abc", add_tags: ["Gidoca triage/ready"])
      end

      it "looks the child up inside its parent" do
        expect(script).to include(%(first tag of theTagParent whose name is "ready"))
      end
    end

    context "when removing a nested tag" do
      subject(:script) do
        described_class.generate_apple_script(item_type: "task", id: "abc", remove_tags: ["Gidoca triage/wontfix"])
      end

      it "does not create the tag" do
        expect(script).not_to include("make new tag")
      end

      it "removes the found tag" do
        expect(script).to include("remove theTag from tags of foundItem")
      end
    end

    context "when replacing tags" do
      subject(:script) do
        described_class.generate_apple_script(item_type: "task", id: "abc", replace_tags: ["Gidoca triage/ready"])
      end

      it "clears existing tags before adding" do
        expect(script.index("remove existingTag from tags of foundItem"))
          .to be < script.index(%(first tag of theTagParent whose name is "ready"))
      end
    end

    context "with note replacements" do
      subject(:script) do
        described_class.generate_apple_script(
          item_type: "task", id: "abc", new_name: "Renamed",
          note_replacements: [{ find: "Status: open", replace: "Status: claimed" }]
        )
      end

      it "checks the note before changing anything" do
        expect(script.index("set noteCheck to evaluate javascript")).to be < script.index("set name of foundItem")
      end

      it "returns the check's error" do
        expect(script).to include(%(\\"error\\":\\"" & my jsonEscape(noteCheck) & "\\"}"))
      end

      it "edits the note's rich text, not the plain note" do
        expect(script).not_to include("set note of foundItem")
      end

      it "reports the change" do
        expect(script).to include(%(set end of changedProperties to "note (replaced text)"))
      end
    end

    context "with appended note text" do
      subject(:script) do
        described_class.generate_apple_script(item_type: "task", id: "abc", append_note: "Answer:\ndone")
      end

      it "edits the note's rich text, not the plain note" do
        expect(script).not_to include("set note of foundItem")
      end

      it "has no check step" do
        expect(script).not_to include("noteCheck")
      end

      it "reports the change" do
        expect(script).to include(%(set end of changedProperties to "note (appended)"))
      end
    end

    context "with a multi-line name" do
      subject(:script) do
        described_class.generate_apple_script(item_type: "task", id: "abc", new_name: "One\nTwo")
      end

      it "collapses the line break to a space" do
        expect(script).to include('set name of foundItem to "One Two"')
      end
    end
  end
end
