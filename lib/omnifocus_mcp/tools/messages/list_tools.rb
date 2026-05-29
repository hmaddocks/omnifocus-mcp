# frozen_string_literal: true

module OmnifocusMcp
  module Tools
    module Messages
      module ListTools
        class << self
          def list_tags_failure(error) = "Failed to list tags: #{error}"
          def list_perspectives_failure(error) = "Failed to list perspectives: #{error}"
          def perspective_view_failure(error) = "Failed to get perspective view: #{error}"
        end
      end
    end
  end
end
