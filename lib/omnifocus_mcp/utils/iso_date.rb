# frozen_string_literal: true

require "date"

require_relative "blank"

module OmnifocusMcp
  module Utils
    # Normalizes date strings to ISO 8601 for machine-oriented output (query
    # results, resource JSON). Human-readable formatting lives in
    # {Tools::Definitions::DateFormatter}.
    #
    module IsoDate
      module_function

      # Return a YYYY-MM-DD string, or +nil+ when the input is blank or
      # unparseable.
      def to_date_only(value)
        return nil if Blank.blank?(value)

        Date.parse(value.to_s).strftime("%Y-%m-%d")
      rescue ArgumentError
        nil
      end
    end
  end
end
