# frozen_string_literal: true

module OmnifocusMcp
  module Utils
    # Lightweight "blank" predicate without pulling in ActiveSupport.
    #
    # A value is *blank* when it is `nil` or its `to_s` is the empty string.
    # The variadic form returns `true` only when **every** argument is blank,
    # which is exactly the shape the audit's hot spots want:
    #
    #     Utils::Blank.blank?(args[:id], args[:name])
    #     # => true when both the id and the name are missing or empty
    #
    # Replaces 12+ hand-rolled `x.nil? || x.to_s.empty?` chains across the
    # codebase (audit item #19).
    module Blank
      module_function

      def blank?(*values)
        return true if values.empty?

        values.all? { |v| v.to_s.empty? }
      end
    end
  end
end
