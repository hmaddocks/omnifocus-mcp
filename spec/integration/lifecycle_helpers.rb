# frozen_string_literal: true

module OmnifocusMcp
  # Self-contained setup helpers for integration lifecycle specs. Each example
  # calls these to build the world it needs without sharing state across examples.
  module IntegrationLifecycleHelpers
    module_function

    def create_inbox_task(name: "TEST:Inbox Task")
      IntegrationActions.create_tracked_task(name: name)
    end

    def create_project_task(name:, project_name:)
      IntegrationActions.create_tracked_task(name: name, project_name: project_name)
    end

    def move_task_to_project(task_id, project_name)
      Tools::Operations::EditItem.call(
        Tools::Params::EditItemParams.from_hash(
          item_type: "task",
          id: task_id,
          new_project_name: project_name
        )
      )
    end

    def inbox_task_in_project(name:, project_name:)
      create = create_inbox_task(name: name)
      return create unless create.ok?

      move = move_task_to_project(create.ok.task_id, project_name)
      return move unless move.ok?

      create
    end

    def find_task(name:, include_completed: false, filters: {})
      result = Tools::Operations::QueryOmnifocus.call(
        Tools::Params::QueryOmnifocusParams.from_hash(
          entity: "tasks",
          filters: { task_name: name, **filters },
          include_completed: include_completed
        )
      )
      return nil unless result.ok?

      (result.ok.items || []).find { |item| item["name"] == name }
    end

    def task_present?(task_id)
      !IntegrationHelpers.resolve_item_name(task_id, :task).nil?
    end
  end
end
