# frozen_string_literal: true

require "json"

require_relative "../../infrastructure/apple_script"

module OmnifocusMcp
  module Tools
    module Generators
      # AppleScript steps for `edit_item`'s `noteReplacements` and `appendNote`.
      #
      # Both edit the note's rich text through Omni Automation (`noteText`),
      # so links, attachments and styles outside the changed text survive.
      # Setting `note of foundItem` from AppleScript would flatten the note.
      module NoteEdit
        # Called as (itemId, mode, startText, replacements, appendText).
        # mode "check" returns "" or an error; mode "apply" edits the note.
        # `startText` is the newNote value when one is set in the same call.
        SCRIPT = <<~'JS'.lines.map(&:strip).join(" ")
          ((id, mode, start, reps, append) => {
            const project = Project.byIdentifier(id);
            const item = Task.byIdentifier(id) || (project ? project.task : null);
            if (!item) return "Item not found";
            if (mode === "check") {
              let s = start === null ? item.noteText.string : start;
              for (const r of reps) {
                if (!s.includes(r.find)) return "Note text not found: " + r.find;
                s = s.split(r.find).join(r.replace);
              }
              return "";
            }
            const text = item.noteText;
            const mark = "";
            const swap = (from, to, times) => {
              for (let i = 0; i < times; i++) {
                const range = text.find(from, null, null);
                if (!range) break;
                text.replace(range, new Text(to, text.style));
              }
            };
            for (const r of reps) {
              const count = text.string.split(r.find).length - 1;
              swap(r.find, mark, count);
              swap(mark, r.replace, count);
            }
            if (append !== null) {
              text.append(new Text((text.string.length > 0 ? "\n" : "") + append, text.style));
            }
            return "";
          })
        JS
        private_constant :SCRIPT

        class << self
          # Fails the edit before anything changes when a `find` is missing.
          def guard_step(params)
            return nil if replacements(params).empty?

            <<~APPLESCRIPT.chomp
              -- Check every note replacement can apply before changing anything
              #{evaluate("noteCheck", params, mode: "check")}
              if noteCheck is not "" then
                return "{\\"success\\":false,\\"error\\":\\"" & my jsonEscape(noteCheck) & "\\"}"
              end if
            APPLESCRIPT
          end

          # Applies replacements, then the append, after any newNote.
          def apply_step(params)
            changes = []
            changes << "note (replaced text)" unless replacements(params).empty?
            changes << "note (appended)" unless params.append_note.nil?
            return nil if changes.empty?

            labels = changes.map { |label| %(set end of changedProperties to "#{label}") }
            <<~APPLESCRIPT.chomp
              -- Edit the note's rich text in place
              #{evaluate("noteEdit", params, mode: "apply")}
              #{labels.join("\n")}
            APPLESCRIPT
          end

          private

          def replacements(params) = Array(params.note_replacements)

          # `set <var> to evaluate javascript (...)`, with the item id spliced
          # in from the AppleScript variable `itemId`.
          def evaluate(var, params, mode:)
            prefix = Infrastructure::AppleScript.escape(%[#{SCRIPT}(])
            suffix = Infrastructure::AppleScript.escape(%[, #{js_args(params, mode).join(", ")})])
            %(tell application "OmniFocus" to set #{var} to evaluate javascript ) +
              %{("#{prefix}" & quote & itemId & quote & "#{suffix}")}
          end

          def js_args(params, mode)
            pairs = replacements(params).map { |r| { find: normalize(r[:find]), replace: normalize(r[:replace]) } }
            [mode, normalize(params.new_note), pairs, normalize(params.append_note)].map { |arg| JSON.generate(arg) }
          end

          def normalize(value) = value&.to_s&.gsub(/\r\n?/, "\n")
        end
      end
    end
  end
end
