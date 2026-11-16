# Changelog

## [1.1]

- Fix `hasNote: false` excluding tasks with empty notes
- Stop task queries returning each project's root task as a task
- Escape names in AppleScript JSON replies so a `"` or `\` in a name no longer makes a saved change report as failed
- Keep line breaks in notes written by `add_omnifocus_task`, `add_project` and `edit_item`
- Support nested tag paths such as `"Work/Mac"` in `tags`, `addTags`, `removeTags` and `replaceTags`. A tag name containing `/` is now read as a path
- Add `appendNote` and `noteReplacements` to `edit_item` so part of a note can change without rewriting it

## [1.0.2]

- Remove `bundler/setup` from the executable so the gem runs correctly when
  installed outside a Bundler-managed environment
- Refactor database stats generator to eliminate circular logic
- Remove unused `BatchReport` and `QueryOmnifocusFormatter` classes
- Reorganise spec suite into per-class files

## [1.0.1] - 2026-06-27

- Fix UTF-8/US-ASCII encoding on stdio so MCP clients receive valid JSON-RPC messages
- Add `--version` / `-v` CLI flags and log server version on startup
- Omit empty date and numeric filters from query result formatting

## [1.0.0] - 2026-05-31

- Initial release
