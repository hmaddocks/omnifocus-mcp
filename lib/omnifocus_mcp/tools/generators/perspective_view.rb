# frozen_string_literal: true

module OmnifocusMcp
  module Tools
    module Generators
      class PerspectiveView
        class << self
          def script_path = "@getPerspectiveView.js"

          def args(perspective_name:, limit:)
            [perspective_name.to_s, limit.to_s]
          end
        end
      end
    end
  end
end
