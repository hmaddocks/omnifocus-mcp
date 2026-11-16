# Server Gap Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the four confirmed server bugs and add the two missing features (nested tag paths, partial note edits) that force Gidoca agents to work around the server with a shell script.

**Architecture:** Every fix lives in the script generators (Ruby that emits AppleScript or Omni Automation JS) plus shared fragments in `Infrastructure::AppleScript`. New AppleScript building blocks (`multiline_string`, `json_escape_handler`, `tag_lookup`) are added there and reused by `AddOmniFocusTask`, `AddProject` and `EditItem`. `batch_add_items` reuses the `AddOmniFocusTask` generator, so it gets every add-side fix for free.

**Tech Stack:** Ruby 4.0, RSpec, fast-mcp, AppleScript and Omni Automation JS run via `osascript`.

**Spec:** The gap list in the Bear note "Why OmniFocus tags and status go through a shell script" (`bear://x-callback-url/open-note?id=965DA43D-6C6B-4910-9802-A7F8DAAA5054`), as checked against the code on 2026-11-17:

1. `hasNote: false` matches nothing.
2. A `"` in an item name breaks the JSON reply of `edit_item`, `add_omnifocus_task` and `add_project` (the change is saved but reported as failed).
3. `AppleScript.escape` turns CR/LF into spaces, so every note the server writes is one line.
4. `query_omnifocus` with `entity: "tasks"` returns each project's root task as a task.
5. Tags are found by bare name only; there is no way to pick "ready-for-agent" inside "Gidoca triage", and nested tags can't be created.
6. `edit_item` can only replace a whole note.

Out of scope: tag inheritance for new sub-actions (OmniFocus behaviour), exact `projectName` matching (`projectId` exists), root tasks in `database_stats` counts.

## Global Constraints

- Follow `AGENTS.md`: `subject` declared above every `let` and `before`; group by `context`; one `expect` per example where practical.
- After every task: `bundle exec rspec` passes and `bundle exec rubocop` reports no offences.
- Tag path separator is `/`, matching the existing folder/project path syntax (`"Work/My Project"`).
- Note text keeps its line breaks as LF. Item **names** keep collapsing line breaks to spaces (`AppleScript.escape` is unchanged).
- Each task adds a bullet to a new `## [Unreleased]` section at the top of `CHANGELOG.md`.

## Review Focus

1. **Tag names that already contain `/`.** After Task 5 a bare tag named `a/b` becomes a path lookup. Expected: a path that resolves nothing with `create: true` creates the nested tags; document this in the tool description. Test in Task 5.
2. **`noteReplacements` whose `find` text is absent.** Expected: error reply naming the missing text, and *no* property on the item changed, even if the same call also sets `newName`. Test in Task 6.
3. **Names containing backslashes, not just quotes.** Expected: reply JSON parses and the name round-trips exactly. Test in Task 3.
4. **Windows line endings (`\r\n`) in notes.** Expected: one LF per line break, not two. Test in Task 4.
5. **`hasNote: false` on a task whose note is only whitespace.** Expected: matches (whitespace counts as no note, per the tool description). Test in Task 1.

---

### Task 1: Fix the `hasNote` filter

**Files:**
- Modify: `lib/omnifocus_mcp/tools/generators/query_omnifocus.rb:286-291` (`apply_task_misc_filters`)
- Test: `spec/omnifocus_mcp/tools/generators/query_omnifocus_spec.rb`

**Interfaces:** none new.

- [ ] **Step 1: Write the failing test.** In a `context "with hasNote filter"`, generate the script with `filters: { has_note: false }` and assert the emitted JS coerces to a boolean:

```ruby
it "compares a boolean note check" do
  expect(script).to include("const hasNote = Boolean(item.note && item.note.trim().length > 0);")
end
```

- [ ] **Step 2: Run** `bundle exec rspec spec/omnifocus_mcp/tools/generators/query_omnifocus_spec.rb` — expect FAIL.
- [ ] **Step 3: Implement** — wrap the expression in `Boolean(...)`. (`"" && …` evaluates to `""`, and `"" !== false` is what drops every empty-note task.)
- [ ] **Step 4: Run** the spec — expect PASS. Run the full suite.
- [ ] **Step 5: Commit** `Fix hasNote: false excluding tasks with empty notes`.

### Task 2: Exclude project root tasks from task queries

**Files:**
- Modify: `lib/omnifocus_mcp/tools/generators/query_omnifocus.rb:514-516`
- Test: `spec/omnifocus_mcp/tools/generators/query_omnifocus_spec.rb`

**Interfaces:** none new.

- [ ] **Step 1: Write the failing test** for `entity: "tasks"`:

```ruby
it "skips project root tasks" do
  expect(script).to include("items = flattenedTasks.filter(task => task.project === null);")
end
```

- [ ] **Step 2: Run** — expect FAIL.
- [ ] **Step 3: Implement.** `Task.project` is non-null only for a project's root task.
- [ ] **Step 4: Run** — expect PASS. Full suite.
- [ ] **Step 5: Commit** `Exclude project root tasks from task queries`.

### Task 3: JSON-safe replies from AppleScript

**Files:**
- Modify: `lib/omnifocus_mcp/infrastructure/apple_script.rb` (`tell_document`, new `json_escape_handler`)
- Modify: `lib/omnifocus_mcp/tools/generators/edit_item.rb:224` (`finalize_and_return`)
- Modify: `lib/omnifocus_mcp/tools/generators/add_omni_focus_task.rb:176-183` (`success_return`)
- Modify: `lib/omnifocus_mcp/tools/generators/add_project.rb:79`
- Test: `spec/omnifocus_mcp/infrastructure/apple_script_spec.rb`, the three generator specs, `spec/integration/task_lifecycle_spec.rb`

**Interfaces:**
- Produces: `AppleScript.json_escape_handler -> String` — a top-level AppleScript handler `on jsonEscape(theText) … end jsonEscape`. Callers inside a `tell` block call it as `my jsonEscape(x)`.
- `tell_document(body)` now appends `json_escape_handler` after `end try`, so every script built with it can call `my jsonEscape`.

- [ ] **Step 1: Write failing unit tests.**
  - `apple_script_spec`: `tell_document("x")` includes `"on jsonEscape(theText)"`; its `on error` branch includes `my jsonEscape(errorMessage)`.
  - `edit_item_spec`: script includes `my jsonEscape(itemName)`.
  - `add_omni_focus_task_spec`: script includes `my jsonEscape(name of newTask)` and no longer embeds the literal escaped name in the reply.
  - `add_project_spec`: script includes `my jsonEscape(name of newProject)`.
- [ ] **Step 2: Write the failing integration test** (`:requires_omnifocus`): create a task named `TEST:Say "hi" \ bye`, edit its note, assert `result.ok.name == 'TEST:Say "hi" \ bye'`.
- [ ] **Step 3: Run** unit specs — expect FAIL.
- [ ] **Step 4: Implement `json_escape_handler`.** Use text item delimiters to replace, in this order: `\` → `\\`, `"` → `\"`, `linefeed` → `\n`, `return` → `\r`, `tab` → `\t`; reset delimiters to `""` before returning. Route every interpolated name/error in the three replies through `my jsonEscape(...)`; build the add-task reply name from `name of newTask`, not the Ruby-escaped input.
- [ ] **Step 5: Run** unit specs — PASS. Run `INTEGRATION=1 bundle exec rspec spec/integration/task_lifecycle_spec.rb` — PASS.
- [ ] **Step 6: Commit** `Escape names in AppleScript JSON replies`.

### Task 4: Keep line breaks in notes

**Files:**
- Modify: `lib/omnifocus_mcp/infrastructure/apple_script.rb` (new `multiline_string`)
- Modify: `add_omni_focus_task.rb:81`, `add_project.rb:39`, `edit_item.rb:148` (`new_note`)
- Test: `apple_script_spec.rb`, the three generator specs, `spec/integration/task_lifecycle_spec.rb`

**Interfaces:**
- Produces: `AppleScript.multiline_string(value) -> String` — escapes `"` and `\` like `escape`, normalises `\r\n` and `\r` to `\n`, and emits each LF as the two-character AppleScript escape `\n`. Result is the *inside* of a quoted literal, same contract as `escape`.

- [ ] **Step 1: Write failing unit tests.**
  - `multiline_string("a\nb")` → `'a\nb'` (backslash + n).
  - `multiline_string("a\r\nb\rc")` → `'a\nb\nc'`.
  - `multiline_string('say "hi"')` → `'say \"hi\"'`.
  - `edit_item` with `new_note: "Status: open\nBody"` includes `set note of foundItem to "Status: open\nBody"` (literal backslash-n).
  - Same shape for `add_omni_focus_task` and `add_project` notes.
- [ ] **Step 2: Write the failing integration test:** add a task with note `"line one\nline two"`, query it back, assert `note == "line one\nline two"`.
- [ ] **Step 3: Run** — FAIL.
- [ ] **Step 4: Implement** `multiline_string` and switch the three note call sites to it. `update_string_property` in `EditItem` takes a new `escaper:` keyword so `name` keeps `escape`.
- [ ] **Step 5: Run** unit + integration — PASS.
- [ ] **Step 6: Commit** `Preserve line breaks in notes`.

### Task 5: Nested tag paths

**Files:**
- Modify: `lib/omnifocus_mcp/infrastructure/apple_script.rb` (new `tag_lookup`, rewrite `tag_assignment`)
- Modify: `add_omni_focus_task.rb:326-337`, `add_project.rb:124-135`, `edit_item.rb:292-369`
- Modify: tag descriptions in `add_omni_focus_task_tool.rb:33`, `add_project_tool.rb:31`, `batch_add_items_tool.rb:36`, `edit_item_tool.rb:48-50`
- Test: `apple_script_spec.rb`, the three generator specs, `spec/integration/task_lifecycle_spec.rb`

**Interfaces:**
- Produces: `AppleScript.tag_lookup(var:, tag_path:, create:) -> String`. `tag_path` is raw (unescaped) text; the method splits on `/`, drops empty parts, escapes each. Sets `var` to the tag or `missing value`.
- Changes: `AppleScript.tag_assignment(item_var:, tag_path:)` (was `tag_name:`; callers now pass the raw tag, not an escaped one). Uses `tag_lookup(create: true)`.

Lookup algorithm for `["A", "B", "C"]`:
1. `A` → `first flattened tag whose name is "A"` (bare names keep today's behaviour).
2. Each later part → `first tag of <current> whose name is "<part>"`.
3. On a miss: with `create: true`, `make new tag with properties {name:"<part>"}` (at `end of tags of <current>` after the first part); with `create: false`, set `var` to `missing value` and skip the remaining parts.

- [ ] **Step 1: Write failing unit tests.**
  - `tag_lookup(var: "t", tag_path: "Gidoca triage/ready-for-agent", create: true)` includes `first flattened tag whose name is "Gidoca triage"` and `first tag of`, and `whose name is "ready-for-agent"`, and `at end of tags of`.
  - With `create: false` the script does not include `make new tag`.
  - A bare `"Mac"` produces no `first tag of`.
  - `"a/b"` (Review Focus 1) is treated as a two-part path.
  - `edit_item` with `remove_tags: ["Gidoca triage/wontfix"]` uses the lookup with `create: false`.
  - `edit_item` with `replace_tags` still clears existing tags first.
- [ ] **Step 2: Write the failing integration test:** create a tag group `TEST:Triage` with child `ready`, plus a top-level `ready`; add a task with `tags: ["TEST:Triage/ready"]`; assert the task's tag id is the child's. Clean up both tags.
- [ ] **Step 3: Run** — FAIL.
- [ ] **Step 4: Implement.** Generate tag blocks per tag in Ruby (drop the AppleScript `repeat with tagName in tagNames` loops in `EditItem`). Update tool descriptions to: `Tags to assign. Use "Parent/Child" to pick a nested tag, e.g. "Gidoca triage/ready-for-agent"; missing tags are created at that path.` (remove: `…missing tags are ignored.`)
- [ ] **Step 5: Run** unit + integration — PASS.
- [ ] **Step 6: Commit** `Support nested tag paths`.

### Task 6: Partial note edits in `edit_item`

**Files:**
- Modify: `lib/omnifocus_mcp/tools/params.rb:27-33` (`EditItemParams` gains `:append_note, :note_replacements`)
- Modify: `lib/omnifocus_mcp/tools/definitions/edit_item_tool.rb`
- Modify: `lib/omnifocus_mcp/tools/generators/edit_item.rb`
- Test: `edit_item_tool_spec.rb`, `edit_item_spec.rb`, `spec/integration/task_lifecycle_spec.rb`

**Interfaces:**
- Consumes: `AppleScript.multiline_string` (Task 4), `my jsonEscape` (Task 3).
- Produces (MCP schema):
  - `appendNote` — `optional(:appendNote).filled(:string)`: appended after the existing note, separated by one LF (no separator when the note is empty).
  - `noteReplacements` — `optional(:noteReplacements).array(:hash) { required(:find).filled(:string); required(:replace).value(:string) }`: each `find` replaced everywhere in the note by `replace`.
- Order when combined: `newNote`, then `noteReplacements`, then `appendNote`.
- Changed-properties labels: `"note (replaced text)"`, `"note (appended)"`.

- [ ] **Step 1: Write failing tests.**
  - Tool spec: `noteReplacements: [{ find: "Status: open", replace: "Status: claimed" }]` reaches the operation as `note_replacements: [{ find: "Status: open", replace: "Status: claimed" }]`.
  - Generator: with `note_replacements`, the script checks `if note of foundItem does not contain "Status: open"` and returns `Note text not found: Status: open` **before** any `set … of foundItem` line (assert the check's index is lower than `set name of foundItem`'s index when `new_name` is also given — Review Focus 2).
  - Generator: with `append_note: "Answer"` the script includes `"Answer"` and `"note (appended)"`.
- [ ] **Step 2: Write the failing integration test:** create a task with note `"Status: open\nDetails"`; call `edit_item` with `noteReplacements` → note is `"Status: claimed\nDetails"`; call again with `appendNote: "Answer: done"` → note ends with `"Details\nAnswer: done"`.
- [ ] **Step 3: Run** — FAIL.
- [ ] **Step 4: Implement.** Put all `does not contain` guards first in `item_found_body`. Do the replacement with an AppleScript text-item-delimiters handler `replaceText(theText, findText, replaceText)` emitted next to `jsonEscape` (only when replacements are present).
- [ ] **Step 5: Run** unit + integration — PASS.
- [ ] **Step 6: Commit** `Add appendNote and noteReplacements to edit_item`.

### Task 7: Live check and docs

**Files:**
- Modify: `README.md` (tool reference for tag paths, `appendNote`, `noteReplacements`)
- Modify: Bear note (spec) — strike the quirks this plan fixed

- [ ] **Step 1:** `INTEGRATION=1 bundle exec rspec` — all pass.
- [ ] **Step 2:** Restart the MCP server (`/mcp`) and by hand: query `Omnifocus MCP` tasks (no root task), add a task with a quoted multi-line note and tag `Gidoca triage/ready-for-agent` to the inbox, flip a `Status:` line with `noteReplacements`, then remove it.
- [ ] **Step 3:** Update README and the Bear note; commit `Document tag paths and partial note edits`.
