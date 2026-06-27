# frozen_string_literal: true

require "fast_mcp"

module OmnifocusMcp
  module Mcp
    extend self

    INSTRUCTIONS = <<~INSTRUCTIONS
      OmniFocus MCP server for macOS task management.

      TOOL GUIDANCE:
      - Use query_omnifocus for targeted lookups; the "fields" parameter requests only needed fields
      - Use "summary: true" for quick counts without full data
      - For batch operations, prefer batch_add_items/batch_remove_items over repeated single calls

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
    INSTRUCTIONS

    def server_name = "OmniFocus MCP"

    def server_version = VERSION

    def build_server(logger: FastMcp::Logger.new)
      FastMcp::Server.new(name: server_name, version: server_version, logger: logger).tap do |server|
        register_tools(server)
        register_resources(server)
      end
    end

    def start
      OmnifocusMcp.logger.warn("Starting #{server_name} v#{server_version}")
      build_server.start
    end

    private

    def register_tools(server)
      server.register_tools(
        Tools::Definitions::AddOmniFocusTaskTool,
        Tools::Definitions::AddProjectTool,
        Tools::Definitions::RemoveItemTool,
        Tools::Definitions::EditItemTool,
        Tools::Definitions::BatchAddItemsTool,
        Tools::Definitions::BatchRemoveItemsTool,
        Tools::Definitions::QueryOmnifocusTool,
        Tools::Definitions::ListPerspectivesTool,
        Tools::Definitions::GetPerspectiveViewTool,
        Tools::Definitions::ListTagsTool
      )
    end

    def register_resources(server)
      server.register_resources(
        Resources::InboxResource,
        Resources::TodayResource,
        Resources::FlaggedResource,
        Resources::StatsResource,
        Resources::ProjectResource,
        Resources::PerspectiveResource
      )
    end
  end
end
