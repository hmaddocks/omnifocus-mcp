# frozen_string_literal: true

module OmnifocusMcp
  # Self-contained setup helpers for integration lifecycle specs. Each example
  # calls these to build the world it needs without sharing state across examples.
  module IntegrationLifecycleHelpers
    module_function

    def create_inbox_task(name: "TEST:Inbox Task")
      IntegrationActions.create_tracked_task(name: name)
    end

    def create_inbox_task_with_tags(name:, tags:)
      IntegrationActions.create_tracked_task(name: name, tags: tags)
    end

    # Create a top-level tag and register it for teardown.
    def create_tracked_tag(name:)
      IntegrationHelpers.assert_test_prefix!(name)
      id = IntegrationHelpers.exec_apple_script(<<~APPLESCRIPT)
        tell application "OmniFocus"
          tell front document
            return id of (make new tag with properties {name:"#{name}"}) as string
          end tell
        end tell
      APPLESCRIPT
      IntegrationSetup.registry.track(id, name, :tag)
    end

    # Name of the tag that contains the task's first tag.
    def first_tag_parent_name(task_id)
      IntegrationHelpers.exec_apple_script(<<~APPLESCRIPT)
        tell application "OmniFocus"
          tell front document
            return name of container of first tag of (first flattened task whose id is "#{task_id}")
          end tell
        end tell
      APPLESCRIPT
    end

    # Register every tag whose name starts with `prefix` for teardown.
    def track_tags_by_prefix(prefix)
      IntegrationHelpers.find_items_by_prefix(prefix, :tag).each do |tag|
        IntegrationSetup.registry.track(tag[:id], tag[:name], :tag)
      end
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
