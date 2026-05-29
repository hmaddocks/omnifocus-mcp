# frozen_string_literal: true

require_relative "setup"

# Opt-in: `INTEGRATION=1 bundle exec rspec spec/integration/project_lifecycle_spec.rb`.
RSpec.describe "Project Lifecycle (integration)", :requires_omnifocus do
  OmnifocusMcp::IntegrationSetup.install!(self)

  let(:registry) { OmnifocusMcp::IntegrationSetup.registry }

  it "creates, edits, adds a task to, and removes a project" do
    create = OmnifocusMcp::IntegrationActions.create_tracked_project(
      name: "TEST:New Project",
      folder_name: registry.run_folder
    )
    expect(create).to be_ok
    project_id = create.ok.project_id
    expect(project_id).not_to be_nil

    edit = OmnifocusMcp::Tools::Operations::EditItem.call(
      item_type: "project",
      id: project_id,
      new_name: "TEST:Edited Project",
      new_sequential: true
    )
    expect(edit).to be_ok
    expect(edit.ok.changed_properties).to include("name", "sequential")

    on_hold = OmnifocusMcp::Tools::Operations::EditItem.call(
      item_type: "project",
      id: project_id,
      new_project_status: "onHold"
    )
    expect(on_hold).to be_ok

    active = OmnifocusMcp::Tools::Operations::EditItem.call(
      item_type: "project",
      id: project_id,
      new_project_status: "active"
    )
    expect(active).to be_ok

    child_task = OmnifocusMcp::IntegrationActions.create_tracked_task(
      name: "TEST:Child Task",
      project_name: "TEST:Edited Project"
    )
    expect(child_task).to be_ok

    remove = OmnifocusMcp::IntegrationActions.safe_remove_tracked(project_id, "project")
    expect(remove).to be_ok
  end
end
