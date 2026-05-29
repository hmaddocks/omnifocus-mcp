# frozen_string_literal: true

module OmnifocusMcp
  module Tools
    module Messages
      module BatchRemoveItems
        class << self
          def missing_identifier = "Each item must have either id or name provided to remove it."
        end
      end
    end
  end
end
