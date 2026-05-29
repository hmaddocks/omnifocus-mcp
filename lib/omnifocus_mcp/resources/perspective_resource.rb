# frozen_string_literal: true

require_relative "base"
require_relative "../tools/operations/get_perspective_view"

module OmnifocusMcp
  module Resources
    # Items visible in a named OmniFocus perspective.
    #
    # `#content` (via `#payload`) is the sole entry point.
    class PerspectiveResource < Base
      uri "omnifocus://perspective/{name}"
      resource_name "perspective"
      description "Items visible in a named OmniFocus perspective"

      def payload
        name = params[:name].to_s
        OmnifocusMcp.logger.warn("[resource:perspective] Reading perspective: #{name}")

        params = Tools::Params::GetPerspectiveViewParams.from_hash(perspective_name: name)
        Tools::Operations::GetPerspectiveView.call(params).fold(
          on_ok: ->(items) { snake_case_keys(items || []) },
          on_error: ->(err) { { error: err } }
        )
      end
    end
  end
end
