# frozen_string_literal: true

require_relative "setup"

# Opt-in: `INTEGRATION=1 bundle exec rspec spec/integration/task_lifecycle_spec.rb`.
RSpec.describe "Task Lifecycle (integration)", :requires_omnifocus do
  OmnifocusMcp::IntegrationSetup.install!(self)

  let(:registry) { OmnifocusMcp::IntegrationSetup.registry }
  let(:helpers) { OmnifocusMcp::IntegrationLifecycleHelpers }
  let(:edit_item) { OmnifocusMcp::Tools::Operations::EditItem }

  context "when creating tasks" do
    context "with an inbox task" do
      subject(:result) { helpers.create_inbox_task(name: task_name) }

      let(:task_name) { "TEST:Inbox Task" }
      let(:task) do
        result.ok.then { helpers.find_task(name: task_name, filters: { inbox: true }) }
      end

      it "creates a queryable inbox task" do
        expect(task).to include("id" => result.ok.task_id)
      end
    end

    context "with a project task" do
      subject(:result) do
        helpers.create_project_task(
          name: task_name,
          project_name: registry.test_project
        )
      end

      let(:task_name) { "TEST:Project Task" }
      let(:task) do
        result.ok.then do
          helpers.find_task(
            name: task_name,
            filters: { project_name: registry.test_project, inbox: false }
          )
        end
      end

      it "creates a queryable task in the test project" do
        expect(task).to include(
          "id" => result.ok.task_id,
          "projectName" => registry.test_project
        )
      end
    end
  end

  context "when moving tasks" do
    context "from the inbox to the test project" do
      subject(:result) do
        edit_item.call(
          item_type: "task",
          id: task_id,
          new_project_name: registry.test_project
        )
      end

      let(:task_name) { "TEST:Move To Project" }
      let(:create_result) { helpers.create_inbox_task(name: task_name) }
      let(:task_id) { create_result.ok.task_id }
      let(:task) do
        result.ok.then do
          helpers.find_task(name: task_name, filters: { project_name: registry.test_project })
        end
      end

      it "moves the task to the project" do
        expect(
          changed_properties: result.ok.changed_properties,
          project_name: task&.fetch("projectName", nil)
        ).to match(
          changed_properties: include("project"),
          project_name: registry.test_project
        )
      end
    end

    context "from one project to another" do
      subject(:result) do
        edit_item.call(
          item_type: "task",
          id: task_id,
          new_project_name: target_project_name
        )
      end

      let(:task_name) { "TEST:Move Between Projects" }
      let(:target_project_name) { "TEST:Second Project" }
      let(:create_result) { helpers.inbox_task_in_project(name: task_name, project_name: registry.test_project) }
      let(:target_project) do
        OmnifocusMcp::IntegrationActions.create_tracked_project(
          name: target_project_name,
          folder_name: registry.run_folder
        )
      end
      let(:task_id) do
        target_project.ok
        create_result.ok.task_id
      end
      let(:task) do
        result.ok.then do
          helpers.find_task(name: task_name, filters: { project_name: target_project_name })
        end
      end

      it "moves the task to the target project" do
        expect(
          changed_properties: result.ok.changed_properties,
          project_name: task&.fetch("projectName", nil)
        ).to match(
          changed_properties: include("project"),
          project_name: target_project_name
        )
      end
    end

    context "from a project back to the inbox" do
      subject(:result) do
        edit_item.call(
          item_type: "task",
          id: task_id,
          new_project_name: ""
        )
      end

      let(:task_name) { "TEST:Move To Inbox" }
      let(:create_result) { helpers.inbox_task_in_project(name: task_name, project_name: registry.test_project) }
      let(:task_id) { create_result.ok.task_id }
      let(:task) { result.ok.then { helpers.find_task(name: task_name) } }

      it "moves the task back to the inbox" do
        expect(
          changed_properties: result.ok.changed_properties,
          present: helpers.task_present?(task_id),
          task: task
        ).to match(
          changed_properties: include("moved to inbox"),
          present: true,
          task: a_hash_including("name" => task_name)
        )
      end
    end
  end

  context "when editing tasks" do
    context "when changing name and flagged status" do
      subject(:result) do
        edit_item.call(
          item_type: "task",
          id: task_id,
          new_name: new_task_name,
          new_flagged: true
        )
      end

      let(:task_name) { "TEST:Edit Task" }
      let(:new_task_name) { "TEST:Renamed Task" }
      let(:create_result) { helpers.create_inbox_task(name: task_name) }
      let(:task_id) { create_result.ok.task_id }
      let(:task) { result.ok.then { helpers.find_task(name: new_task_name) } }

      it "updates both properties" do
        expect(
          changed_properties: result.ok.changed_properties,
          task: task
        ).to match(
          changed_properties: include("name", "flagged"),
          task: a_hash_including("flagged" => true)
        )
      end
    end

    context "when marking a task complete" do
      subject(:result) do
        edit_item.call(
          item_type: "task",
          id: task_id,
          new_status: "completed"
        )
      end

      let(:task_name) { "TEST:Complete Task" }
      let(:create_result) { helpers.create_inbox_task(name: task_name) }
      let(:task_id) { create_result.ok.task_id }
      let(:task) { result.ok.then { helpers.find_task(name: task_name, include_completed: true) } }

      it "marks the task completed" do
        expect(task).to include("taskStatus" => "Completed")
      end
    end

    context "when marking a completed task incomplete" do
      subject(:result) do
        complete_result.ok
        edit_item.call(
          item_type: "task",
          id: task_id,
          new_status: "incomplete"
        )
      end

      let(:task_name) { "TEST:Incomplete Task" }
      let(:create_result) { helpers.create_inbox_task(name: task_name) }
      let(:task_id) { create_result.ok.task_id }
      let(:complete_result) do
        edit_item.call(
          item_type: "task",
          id: task_id,
          new_status: "completed"
        )
      end
      let(:task) { result.ok.then { helpers.find_task(name: task_name) } }

      it "makes the task available again" do
        expect(task).to include("taskStatus" => "Available")
      end
    end

    context "when marking a task dropped" do
      subject(:result) do
        edit_item.call(
          item_type: "task",
          id: task_id,
          new_status: "dropped"
        )
      end

      let(:task_name) { "TEST:Drop Task" }
      let(:create_result) { helpers.create_inbox_task(name: task_name) }
      let(:task_id) { create_result.ok.task_id }
      let(:task) do
        result.ok.then do
          helpers.find_task(
            name: task_name,
            include_completed: true,
            filters: { status: ["Dropped"] }
          )
        end
      end

      it "marks the task dropped" do
        expect(task).to include("taskStatus" => "Dropped")
      end
    end
  end

  context "when removing tasks" do
    subject(:result) do
      OmnifocusMcp::IntegrationActions.safe_remove_tracked(task_id, "task")
    end

    let(:task_name) { "TEST:Remove Task" }
    let(:create_result) do
      helpers.create_project_task(
        name: task_name,
        project_name: registry.test_project
      )
    end
    let(:task_id) { create_result.ok.task_id }

    it "removes a project task" do
      result.ok
      expect(helpers.task_present?(task_id)).to be false
    end
  end

  context "when operations fail" do
    subject(:result) do
      edit_item.call(
        item_type: "task",
        id: "nonexistent-task-id",
        new_name: "TEST:Ghost Task"
      )
    end

    it "returns an error when editing a nonexistent task" do
      expect(result).to be_error
    end
  end
end
