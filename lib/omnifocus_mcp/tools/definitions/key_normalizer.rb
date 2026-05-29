# frozen_string_literal: true

module OmnifocusMcp
  module Tools
    module Definitions
      module KeyNormalizer
        class << self
          def snake_keys(obj, deep: false)
            case obj
            when Hash
              obj.each_with_object({}) do |(k, v), out|
                out[snake_case_key(k)] = deep ? snake_keys(v, deep: true) : v
              end
            when Array
              deep ? obj.map { |item| snake_keys(item, deep: true) } : obj
            else
              obj
            end
          end

          def snake_case_key(key)
            return key unless key.is_a?(Symbol) || key.is_a?(String)

            key.to_s.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.to_sym
          end
        end
      end
    end
  end
end
