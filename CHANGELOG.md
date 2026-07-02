# Changelog

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
