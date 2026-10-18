# frozen_string_literal: true

require "fast_mcp"
require "json"

module OmnifocusMcp
  module Resources
    # Shared superclass for OmniFocus MCP resources.
    #
    # All resources serialize a Ruby object as pretty-printed JSON. Subclasses
    # implement `#payload` to produce that Ruby object.
    #
    # MCP resources return:
    #   { contents: [{ uri, mimeType: "application/json", text: pretty_json }] }
    # `FastMcp::Server#handle_resources_read` wraps the `#content` string with
    # the equivalent `contents` envelope (see fast-mcp's resource.rb).
    class Base < FastMcp::Resource
      mime_type "application/json"

      def content = JSON.pretty_generate(camelize_keys(safe_payload))

      # Subclasses must implement.
      # @return [Object] anything `JSON.pretty_generate` can serialize
      def payload = raise NotImplementedError, "#{self.class} must implement #payload"

      private

      def safe_payload
        payload
      rescue StandardError, NotImplementedError => e
        scope = self.class.resource_name || self.class.name
        OmnifocusMcp.logger.warn("[resource:#{scope}] #{e.message}")
        { error: e.message }
      end

      def snake_case_keys(obj) = Tools::Definitions::KeyNormalizer.snake_keys(obj, deep: true)

      def camelize_keys(obj) = Tools::Definitions::KeyNormalizer.camel_keys(obj)

      public

      # Swallows failures into an empty array rather than
      # surfacing an `{ error: ... }` envelope. Used by aggregated resources (e.g.
      # `TodayResource`) that bundle multiple queries and prefer a missing section to
      # an inline error.
      def items_or_empty(result)
        result.map { |match| snake_case_keys(match.items || []) }
              .ok_or([])
      end
    end
  end
end
