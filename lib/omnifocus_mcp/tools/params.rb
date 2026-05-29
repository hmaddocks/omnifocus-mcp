# frozen_string_literal: true

require_relative "params/mcp_boundary"

module OmnifocusMcp
  module Tools
    # Typed input objects for tool primitives. MCP tools build these via
    # {.from_mcp}; other callers (resources, integration specs) use {.from_hash}.
    module Params
      AddTaskParams = Data.define(
        :name, :note, :due_date, :defer_date, :planned_date,
        :flagged, :estimated_minutes, :tags, :project_name,
        :parent_task_id, :parent_task_name, :hierarchy_level
      ) do
        def self.from_mcp(args) = McpBoundary.build(self, args)
        def self.from_hash(hash) = McpBoundary.from_hash(self, hash)
      end

      AddProjectParams = Data.define(
        :name, :note, :due_date, :defer_date, :flagged,
        :estimated_minutes, :tags, :folder_name, :sequential
      ) do
        def self.from_mcp(args) = McpBoundary.build(self, args)
        def self.from_hash(hash) = McpBoundary.from_hash(self, hash)
      end

      EditItemParams = Data.define(
        :id, :name, :item_type, :new_name, :new_note,
        :new_due_date, :new_defer_date, :new_planned_date, :new_flagged,
        :new_estimated_minutes, :new_status, :add_tags, :remove_tags,
        :replace_tags, :new_project_name, :new_sequential, :new_folder_name,
        :new_project_status
      ) do
        def self.from_mcp(args) = McpBoundary.build(self, args)
        def self.from_hash(hash) = McpBoundary.from_hash(self, hash)
      end

      RemoveItemParams = Data.define(:id, :name, :item_type) do
        def self.from_mcp(args) = McpBoundary.build(self, args)
        def self.from_hash(hash) = McpBoundary.from_hash(self, hash)
      end

      QueryOmnifocusParams = Data.define(
        :entity, :filters, :fields, :limit, :sort_by, :sort_order,
        :include_completed, :format, :summary
      ) do
        def self.from_mcp(args) = McpBoundary.build(self, args, deep: true)
        def self.from_hash(hash) = McpBoundary.from_hash(self, hash)
      end

      BatchAddItemParams = Data.define(
        :type, :name, :note, :due_date, :defer_date, :planned_date,
        :flagged, :estimated_minutes, :tags, :project_name, :parent_task_id,
        :parent_task_name, :temp_id, :parent_temp_id, :hierarchy_level,
        :folder_name, :sequential
      ) do
        def self.from_mcp(args) = McpBoundary.build(self, args)
        def self.from_hash(hash) = McpBoundary.from_hash(self, hash)
      end

      BatchRemoveItemParams = Data.define(:id, :name, :item_type) do
        def self.from_mcp(args) = McpBoundary.build(self, args)
        def self.from_hash(hash) = McpBoundary.from_hash(self, hash)
      end

      ListPerspectivesParams = Data.define(:include_built_in, :include_custom) do
        def self.from_mcp(args)
          new(
            include_built_in: args.fetch(:includeBuiltIn, true),
            include_custom: args.fetch(:includeCustom, true)
          )
        end

        def self.from_hash(hash)
          new(
            include_built_in: hash.fetch(:include_built_in, true),
            include_custom: hash.fetch(:include_custom, true)
          )
        end
      end

      ListTagsParams = Data.define(:include_dropped) do
        def self.from_mcp(args) = new(include_dropped: args[:includeDropped] || false)
        def self.from_hash(hash) = new(include_dropped: hash.fetch(:include_dropped, false))
      end

      GetPerspectiveViewParams = Data.define(:perspective_name, :limit, :fields) do
        def self.from_mcp(args)
          new(
            perspective_name: args[:perspectiveName],
            limit: args[:limit],
            fields: args[:fields]
          )
        end

        def self.from_hash(hash)
          new(
            perspective_name: hash[:perspective_name],
            limit: hash[:limit],
            fields: hash[:fields]
          )
        end
      end
    end
  end
end
