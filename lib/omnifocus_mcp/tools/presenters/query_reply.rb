# frozen_string_literal: true

require "json"

require_relative "query_results"

module OmnifocusMcp
  module Tools
    module Presenters
      module QueryReply
        class << self
          def format(args:, params:, match:)
            return JSON.pretty_generate(json_payload(args:, params:, match:)) if output_format(params) == "json"
            return "Found #{match.count} #{params.entity} matching your criteria." if params.summary

            items = match.items || []
            output = QueryResults.format_query_results(items:, entity: params.entity, filters: args[:filters])
            output += limit_warning(params.limit) if params.limit && items.length == params.limit
            output
          end

          def failure(error) = "Query failed: #{error}"

          private

          def output_format(params)
            params.respond_to?(:to_h) ? params.to_h[:format] : nil
          end

          def json_payload(args:, params:, match:)
            {
              entity: params.entity,
              count: match.count,
              items: match.items,
              filters: args[:filters] || {},
              fields: params.fields,
              limit: params.limit,
              sortBy: args[:sortBy],
              sortOrder: params.sort_order,
              includeCompleted: params.include_completed == true,
              summary: params.summary == true
            }
          end

          def limit_warning(limit)
            "\n\n⚠️ Results limited to #{limit} items. More may be available."
          end
        end
      end
    end
  end
end
