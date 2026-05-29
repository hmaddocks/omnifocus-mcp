# frozen_string_literal: true

require "date"

module OmnifocusMcp
  module Utils
    # Parses MCP date-filter wire values and converts them to days-from-today.
    #
    # Named filters are modeled as symbols (`:today`, `:tomorrow`, …) after
    # parsing; only string input is accepted at the MCP boundary. Numeric and
    # ISO-date inputs resolve directly to day offsets.
    #
    module DateFilter
      STRING_TO_NAMED = {
        "today" => :today,
        "tomorrow" => :tomorrow,
        "this week" => :this_week,
        "next week" => :next_week
      }.freeze

      ISO_DATE_RE = /\A\d{4}-\d{2}-\d{2}\z/

      # Parse an MCP wire value into a Ruby-native filter (Symbol or Numeric).
      #
      # `today:` defaults to `Date.today` so ISO dates are resolved relative to a
      # pinned reference date in tests.
      class << self
        def parse(input, today: Date.today)
          return input if input.is_a?(Numeric)
          return input if input.is_a?(Symbol)

          raise_invalid!(input) unless input.is_a?(String) && !input.empty?

          normalized = input.strip.downcase
          return STRING_TO_NAMED[normalized] if STRING_TO_NAMED.key?(normalized)
          return (parse_iso_date(normalized:, original: input) - today).to_i if ISO_DATE_RE.match?(normalized)

          raise_invalid!(input)
        end

        # Convert a parsed filter to a days-from-`today` Integer for query scripts.
        def to_days(filter)
          case filter
          when :today     then 0
          when :tomorrow  then 1
          when :this_week then 7
          when :next_week then 14
          when Numeric    then filter
          else
            raise ArgumentError, "expected Symbol or Numeric date filter, got #{filter.inspect}"
          end
        end

        # MCP boundary helper: parse and convert to days in one step.
        def resolve(input, today: Date.today)
          to_days(parse(input, today: today))
        end

        private

        def parse_iso_date(normalized:, original:)
          Date.iso8601(normalized)
        rescue Date::Error
          raise_invalid!(original)
        end

        def raise_invalid!(input)
          raise ArgumentError,
                "Invalid date filter value: \"#{input}\". " \
                'Use a number, "today", "tomorrow", "this week", "next week", ' \
                "or an ISO date (YYYY-MM-DD)."
        end
      end
    end
  end
end
