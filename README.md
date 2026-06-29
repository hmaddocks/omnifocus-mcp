# omnifocus-mcp (Ruby)

`omnifocus-mcp` is a Ruby MCP server that lets LLM clients (Claude Code / Desktop,
Cursor, Zed, etc.) work with OmniFocus on macOS over stdio. It exposes tools and
resources for creating, editing, removing, querying, and reporting on OmniFocus
tasks, projects, perspectives, and tags.

This tool was heavily inspired by [OmniFocus MCP Server](https://github.com/themotionmachine/OmniFocus-MCP).

## Features

- Create, edit, remove, and query OmniFocus tasks.
- Add and manage projects.
- List tags and perspectives.
- Read common OmniFocus views such as inbox, today, flagged, stats, projects,
  and perspectives.

## Tools and Resources

### Tools

- `add_omnifocus_task` - Adds a new task to OmniFocus, with optional notes,
  dates, tags, project placement, and parent task placement.
- `add_project` - Adds a new project to OmniFocus, with optional notes, dates,
  tags, folder placement, and sequential task ordering.
- `remove_item` - Removes a task or project by ID, or by name when an ID is not
  available.
- `edit_item` - Updates a task or project, including names, notes, dates, flags,
  estimates, statuses, tags, and location.
- `batch_add_items` - Adds multiple tasks or projects in one operation,
  including support for task hierarchy within the batch.
- `batch_remove_items` - Removes multiple tasks or projects in one operation.
- `query_omnifocus` - Queries tasks, projects, or folders with filters for
  project, tag, status, dates, flags, notes, and more.
- `list_perspectives` - Lists built-in and custom OmniFocus perspectives.
- `get_perspective_view` - Returns the tasks and projects visible in a named
  OmniFocus perspective.
- `list_tags` - Lists OmniFocus tags and their hierarchy, with optional inactive
  tags.

### Resources

- `omnifocus://inbox` - Returns current OmniFocus inbox tasks.
- `omnifocus://today` - Returns today's agenda, including tasks due today,
  planned for today, and overdue tasks.
- `omnifocus://flagged` - Returns flagged OmniFocus tasks.
- `omnifocus://stats` - Returns a quick overview of OmniFocus database statistics.
- `omnifocus://project/{name}` - Returns tasks in the named OmniFocus project.
- `omnifocus://perspective/{name}` - Returns items visible in the named
  OmniFocus perspective.

## Requirements

- Ruby 3.4 or later
- macOS with OmniFocus 4 installed

## Install

```sh
gem install omnifocus-mcp
```

## Configure an MCP Client

After installing the executable, add this config to any MCP client that supports
stdio servers:

```json
{
  "mcpServers": {
    "omnifocus-mcp": {
      "command": "omnifocus-mcp",
      "args": []
    }
  }
}
```

## Client Instructions

This server uses [fast-mcp](https://github.com/yjacquin/fast-mcp) 1.6, which
does not currently expose MCP server instructions during client initialization.
To give an MCP client better guidance, copy the instructions below into a skill,
rule, your project's `AGENTS.md`, or your client-specific instruction file.

```text
OmniFocus MCP server for macOS task management.

TOOL GUIDANCE:
- Use query_omnifocus for targeted lookups; the "fields" parameter requests only
  needed fields
- Use "summary: true" for quick counts without full data
- For batch operations, prefer batch_add_items/batch_remove_items over repeated
  single calls

RESOURCES:
- omnifocus://inbox - current inbox items
- omnifocus://today - today's agenda (due, planned, overdue)
- omnifocus://flagged - all flagged items
- omnifocus://stats - quick database statistics
- omnifocus://project/{name} - tasks in a specific project
- omnifocus://perspective/{name} - items in a named perspective

QUERY FILTER TIPS:
- Tags filter is case-sensitive and exact match
- projectName filter is case-insensitive partial match
- Status values for tasks: Next, Available, Blocked, DueSoon, Overdue
- Status values for projects: Active, OnHold, Done, Dropped
- Combine filters with AND logic; within arrays, OR logic applies
```

## Tests

```sh
bundle exec rspec
```

Integration specs that hit the real OmniFocus app are tagged
`:requires_omnifocus` and skipped by default. Run them with:

```sh
INTEGRATION=1 bundle exec rspec
```

OmniFocus must be running and macOS must allow the terminal app to send Apple
Events to OmniFocus. If macOS reports
`Not authorised to send Apple events to OmniFocus (-1743)`, grant the terminal
permission in System Settings > Privacy & Security > Automation.

Integration tests create items prefixed `TEST:` and clean them up at teardown.
If a run is killed mid-flight, you can sweep leftover items with:

```sh
bundle exec ruby spec/integration/cleanup.rb
```

You should backup your OmniFocus database before using this tool. Refer to the
warranty information in the LICENSE.
