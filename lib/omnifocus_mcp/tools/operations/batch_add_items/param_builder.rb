# frozen_string_literal: true

require_relative "../../params"

module OmnifocusMcp
  module Tools
    module Operations
      class BatchAddItems
        # Build typed param objects for nested add primitives from a batch item.
        module ParamBuilder
          class << self
            def project(payload)
              Params::AddProjectParams.new(
                name: payload.name,
                note: payload.note,
                due_date: payload.due_date,
                defer_date: payload.defer_date,
                flagged: payload.flagged,
                estimated_minutes: payload.estimated_minutes,
                tags: payload.tags,
                folder_name: payload.folder_name,
                sequential: payload.sequential
              )
            end

            def task(payload, parent_task_id:, project_name:)
              Params::AddTaskParams.new(
                name: payload.name,
                note: payload.note,
                due_date: payload.due_date,
                defer_date: payload.defer_date,
                planned_date: payload.planned_date,
                flagged: payload.flagged,
                estimated_minutes: payload.estimated_minutes,
                tags: payload.tags,
                project_name: project_name,
                parent_task_id: parent_task_id,
                parent_task_name: payload.parent_task_name,
                hierarchy_level: payload.hierarchy_level
              )
            end
          end
        end
      end
    end
  end
end
