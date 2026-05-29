# frozen_string_literal: true

require_relative "helpers"

module OmnifocusMcp
  # In-memory bookkeeping for items the integration suite creates so they
  # can be safely deleted at teardown time.
  #
  class TestRegistry
    ITEM_TYPES = %i[task project tag folder].freeze

    TrackedItem = Struct.new(:id, :name, :type, keyword_init: true)

    attr_reader :run_folder, :test_project
    attr_accessor :run_folder_id, :test_project_id

    def initialize
      @items = {}
      @run_folder = "TEST:#{(Time.now.to_f * 1000).to_i}"
      @test_project = "TEST:Sample Project"
      @run_folder_id = ""
      @test_project_id = ""
    end

    def track(id, name, type)
      @items[id] = TrackedItem.new(id: id, name: name, type: type)
    end

    def by_type(type)
      @items.values.select { |item| item.type == type }
    end

    def untrack(id)
      @items.delete(id)
    end

    # Delete every tracked item, tasks first so projects/folders can be removed
    # cleanly afterwards. Warnings are emitted on stderr; cleanup never raises.
    def cleanup_all!
      ITEM_TYPES.each do |type|
        by_type(type).each do |item|
          OmnifocusMcp::IntegrationHelpers.safe_delete_by_id(item.id, item.type)
          untrack(item.id)
        rescue StandardError => e
          warn "Cleanup warning: failed to delete #{item.type} #{item.name.inspect} (#{item.id}): #{e}"
        end
      end
    end
  end
end
