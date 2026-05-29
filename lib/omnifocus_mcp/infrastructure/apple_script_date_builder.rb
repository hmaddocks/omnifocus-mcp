# frozen_string_literal: true

require "securerandom"
require "time"

module OmnifocusMcp
  module Infrastructure
    # Builds AppleScript date fragments outside tell blocks so date variables can
    # be safely referenced inside OmniFocus tell blocks.
    class AppleScriptDateBuilder
      ISO_DATE_ONLY_RE = /\A\d{4}-\d{2}-\d{2}\z/

      DateAssignmentParts = Data.define(:pre_script, :assignment_script)

      class << self
        # Generate AppleScript to construct a date variable outside `tell` blocks.
        def create_date_outside_tell_block(iso_date_string, var_name)
          emit_date_assignment(parse_iso(iso_date_string), var_name)
        end

        # Return the scripts needed to assign or clear a date property.
        def generate_date_assignment(object_name, property_name, iso_date_string)
          return nil if iso_date_string.nil?

          if iso_date_string == ""
            return DateAssignmentParts.new(
              pre_script: "",
              assignment_script: "set #{property_name} of #{object_name} to missing value"
            )
          end

          var_name = "dateVar#{SecureRandom.hex(5)}"

          DateAssignmentParts.new(
            pre_script: create_date_outside_tell_block(iso_date_string, var_name),
            assignment_script: "set #{property_name} of #{object_name} to #{var_name}"
          )
        end

        private

        def parse_iso(iso_date_string)
          # Date-only strings are normalized to local midnight, avoiding timezone
          # shifts that can happen when JS interprets YYYY-MM-DD as UTC.
          normalized = ISO_DATE_ONLY_RE.match?(iso_date_string) ? "#{iso_date_string}T00:00:00" : iso_date_string
          Time.parse(normalized)
        rescue ArgumentError, TypeError
          raise ArgumentError, "Invalid date string: #{iso_date_string}"
        end

        def emit_date_assignment(time, var_name)
          <<~APPLESCRIPT.chomp
            copy current date to #{var_name}
            set year of #{var_name} to #{time.year}
            set month of #{var_name} to #{time.month}
            set day of #{var_name} to #{time.day}
            set hours of #{var_name} to #{time.hour}
            set minutes of #{var_name} to #{time.min}
            set seconds of #{var_name} to #{time.sec}
          APPLESCRIPT
        end
      end
    end
  end
end
