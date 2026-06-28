# frozen_string_literal: true

require "date"

require_relative "../../utils/blank"
require_relative "../../utils/iso_date"

module OmnifocusMcp
  module Tools
    module Definitions
      module DateFormatter
        class << self
          def format_date(iso, style:)
            return "" if Utils::Blank.blank?(iso)

            case style
            when :locale  then format_parsed(iso) { |d| us_short_date(d) }
            when :compact then format_parsed(iso) { |d| us_compact_date(d) }
            when :iso     then Utils::IsoDate.to_date_only(iso)
            else raise ArgumentError, "Unknown date style: #{style.inspect}"
            end
          end

          private

          def us_short_date(date)
            format("%<month>d/%<day>d/%<year>d", month: date.month, day: date.day, year: date.year)
          end

          def us_compact_date(date)
            format("%<month>d/%<day>d", month: date.month, day: date.day)
          end

          def format_parsed(iso)
            yield Date.parse(iso.to_s)
          rescue ArgumentError
            ""
          end
        end
      end
    end
  end
end
