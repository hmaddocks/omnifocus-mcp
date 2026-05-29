# frozen_string_literal: true

require_relative "../definitions/key_normalizer"

module OmnifocusMcp
  module Tools
    module Params
      # Builds {Data.define} param structs from MCP wire args or snake_case Hashes.
      module McpBoundary
        class << self
          # @param klass [Data] struct class whose +members+ list snake_case fields
          # @param args [Hash] raw MCP arguments (camelCase Symbol keys)
          # @param deep [Boolean] recurse into nested Hashes and Arrays of Hashes
          def build(klass, args, deep: false)
            snake = Definitions::KeyNormalizer.snake_keys(args, deep: deep)
            from_snake_hash(klass, snake)
          end

          # @param klass [Data]
          # @param hash [Hash] snake_case Symbol keys (e.g. from tests or resources)
          def from_hash(klass, hash)
            from_snake_hash(klass, hash || {})
          end

          def from_snake_hash(klass, snake)
            klass.new(**klass.members.to_h { |member| [member, snake[member]] })
          end

          # Accept a param struct or a snake_case Hash (e.g. specs, script helpers).
          def coerce(klass, value)
            case value
            when klass then value
            when Hash then klass.from_hash(value)
            else raise ArgumentError, "expected #{klass.name}, got #{value.class}"
            end
          end
        end
      end
    end
  end
end
