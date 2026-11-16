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

      it "checks the find text is present" do
        expect(script).to include(%(if (note of foundItem) does not contain "Status: open" then))
      end

      it "reports missing find text" do
        expect(script).to include(%(Note text not found: " & my jsonEscape("Status: open")))
      end

      it "checks before changing anything" do
        expect(script.index("does not contain")).to be < script.index("set name of foundItem")
      end

      it "replaces the text" do
        expect(script).to include(%(my replaceText(note of foundItem, "Status: open", "Status: claimed")))
      end

      it "defines the replaceText handler" do
        expect(script).to include("on replaceText(theText, findText, replacementText)")
      end

      it "reports the change" do
        expect(script).to include(%(set end of changedProperties to "note (replaced text)"))
      end
    end

    context "with appended note text" do
      subject(:script) do
        described_class.generate_apple_script(item_type: "task", id: "abc", append_note: "Answer:\ndone")
      end

      it "appends after a line break when the note is not empty" do
        expect(script).to include(%(set note of foundItem to (note of foundItem) & linefeed & "Answer:\\ndone"))
      end

      it "reports the change" do
        expect(script).to include(%(set end of changedProperties to "note (appended)"))
      end

      it "does not define replaceText" do
        expect(script).not_to include("on replaceText")
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
