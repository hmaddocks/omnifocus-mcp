# frozen_string_literal: true

# Standalone cleanup script. Deletes every OmniFocus item whose name starts
# with the `TEST:` integration prefix. Useful if a previous run was killed
# before its `after(:all)` could fire.
#
# Run with:
#   bundle exec ruby spec/integration/cleanup.rb
#
require_relative "helpers"

module OmnifocusMcp
  module IntegrationCleanup
    module_function

    TYPES = %i[task project tag folder].freeze

    def run!
      TYPES.each do |type|
        items = IntegrationHelpers.find_items_by_prefix(IntegrationHelpers::TEST_PREFIX, type)
        next if items.empty?

        items.each do |item|
          IntegrationHelpers.safe_delete_by_id(item[:id], type)
        rescue StandardError => e
          warn "    FAILED to delete #{item[:name]}: #{e.message}"
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  $LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
  require "omnifocus_mcp"

  begin
    OmnifocusMcp::IntegrationCleanup.run!
  rescue StandardError => e
    warn "Cleanup failed: #{e.message}"
    exit 1
  end
end
