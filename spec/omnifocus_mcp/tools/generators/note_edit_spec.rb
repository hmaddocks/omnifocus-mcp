# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/note_edit"
require "omnifocus_mcp/tools/params"

RSpec.describe OmnifocusMcp::Tools::Generators::NoteEdit do
  let(:params) do
    OmnifocusMcp::Tools::Params::EditItemParams.from_hash(
      item_type: "task", id: "abc", new_note: new_note,
      note_replacements: [{ find: "Status: \"open\"", replace: "Status:\r\nclaimed" }],
      append_note: nil
    )
  end
  let(:new_note) { nil }

  describe ".guard_step" do
    subject(:step) { described_class.guard_step(params) }

    it "passes the item id from AppleScript" do
      expect(step).to include(%(& quote & itemId & quote &))
    end

    it "runs the check mode" do
      expect(step).to include(%(\\"check\\"))
    end

    it "passes the find text as escaped JSON" do
      expect(step).to include('{\\"find\\":\\"Status: \\\\\\"open\\\\\\"\\"')
    end

    it "normalises CRLF in the replacement" do
      expect(step).to include('\\"replace\\":\\"Status:\\\\nclaimed\\"')
    end

    it "checks against the current note when no newNote is given" do
      expect(step).to include(%(\\"check\\", null,))
    end

    context "with newNote in the same call" do
      let(:new_note) { "Status: \"open\"" }

      it "checks against the new note" do
        expect(step).to include(%(\\"check\\", \\"Status: \\\\\\"open\\\\\\"\\",))
      end
    end
  end

  describe ".apply_step" do
    subject(:step) { described_class.apply_step(params) }

    it "runs the apply mode" do
      expect(step).to include(%(\\"apply\\"))
    end

    it "replaces through the rich text" do
      expect(step).to include("text.replace(range, new Text(to, text.style))")
    end
  end
end
