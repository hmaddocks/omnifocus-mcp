# frozen_string_literal: true

require_relative "base"
require_relative "../tools/operations/query_omnifocus"

module OmnifocusMcp
  module Resources
    # Tasks in a specific OmniFocus project, addressed by name.
    #
    # `#content` (via `#payload`) is the sole entry point.
    class ProjectResource < Base
      uri "omnifocus://project/{name}"
      resource_name "project"
      description "Tasks in a specific OmniFocus project"

      FIELDS = %w[
        id name flagged dueDate deferDate taskStatus
        tagNames parentId note estimatedMinutes
      ].freeze

      def payload
        name = params[:name].to_s
        OmnifocusMcp.logger.warn("[resource:project] Reading project: #{name}")

        params = Tools::Params::QueryOmnifocusParams.from_hash(
          entity: "tasks",
          filters: { project_name: name },
          fields: FIELDS
        )
        Tools::Operations::QueryOmnifocus.call(params).fold(
          on_ok: ->(match) { snake_case_keys(match.items || []) },
          on_error: ->(err) { { error: err } }
        )
      end
    end
  end
end
