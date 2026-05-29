# frozen_string_literal: true

require_relative "helpers"
require_relative "lifecycle_helpers"
require_relative "registry"

module OmnifocusMcp
  # Shared `before(:all)` / `after(:all)` plumbing for integration specs.
  #
  # Shared registry lives on `IntegrationSetup`; `.install!` wires
  # `before(:all)` / `after(:all)` hooks into the current example group.
  #
  module IntegrationSetup
    class << self
      attr_accessor :registry
    end

    def self.install!(example_group)
      example_group.before(:all) do
        OmnifocusMcp::IntegrationSetup.build_registry!
      rescue OmnifocusMcp::IntegrationHelpers::OmniFocusAccessError => e
        skip e.message
      end
      example_group.after(:all) { OmnifocusMcp::IntegrationSetup.teardown_registry! }
    end

    def self.build_registry!
      OmnifocusMcp::IntegrationHelpers.assert_omnifocus_running!
      registry = TestRegistry.new

      folder_id = OmnifocusMcp::IntegrationHelpers.create_folder(registry.run_folder)
      registry.run_folder_id = folder_id
      registry.track(folder_id, registry.run_folder, :folder)

      proj_result = Tools::Operations::AddProject.call(
        Tools::Params::AddProjectParams.from_hash(
          name: registry.test_project,
          folder_name: registry.run_folder
        )
      )
      raise "Failed to create test project: #{proj_result.error.inspect}" unless proj_result.ok?

      project_id = proj_result.ok.project_id
      registry.test_project_id = project_id
      registry.track(project_id, registry.test_project, :project)

      self.registry = registry
    end

    def self.teardown_registry!
      registry&.cleanup_all!
      self.registry = nil
    end
  end

  # Higher-level helpers that wrap the write primitives so callers don't
  # have to remember to `track`/`untrack` themselves.
  module IntegrationActions
    module_function

    def create_tracked_task(params)
      result = Tools::Operations::AddOmniFocusTask.call(Tools::Params::AddTaskParams.from_hash(params))
      registry.track(result.ok.task_id, params[:name], :task) if result.ok? && result.ok.task_id
      result
    end

    def create_tracked_project(params)
      result = Tools::Operations::AddProject.call(Tools::Params::AddProjectParams.from_hash(params))
      registry.track(result.ok.project_id, params[:name], :project) if result.ok? && result.ok.project_id
      result
    end

    def safe_remove_tracked(id, item_type)
      result = Tools::Operations::RemoveItem.call(
        Tools::Params::RemoveItemParams.from_hash(id: id, item_type: item_type)
      )
      registry.untrack(id) if result.ok?
      result
    end

    def registry
      OmnifocusMcp::IntegrationSetup.registry
    end
  end
end
