# frozen_string_literal: true

module OmnifocusMcp
  module Tools
    module Definitions
      module OperationFactory
        def self.extended(base)
          base.include InstanceMethods
        end

        def default_operation_factory(&factory)
          @default_operation_factory = factory
        end

        def operation_factory
          @operation_factory || @default_operation_factory
        end

        def operation_factory=(factory)
          @operation_factory = factory
        end

        module InstanceMethods
          private

          def operation
            self.class.operation_factory.call
          end
        end
      end
    end
  end
end
