# frozen_string_literal: true

require_relative "../../infrastructure/apple_script"
require_relative "../../utils/blank"
require_relative "../params"

module OmnifocusMcp
  module Tools
    module Generators
      class RemoveItem
        class << self
          def generate_apple_script(params = nil, **kwargs)
            merge_params(params, kwargs).then do |params|
              params = Params::McpBoundary.coerce(Params::RemoveItemParams, params)
              return missing_identifier_error if Utils::Blank.blank?(params.id, params.name)

              id = Infrastructure::AppleScript.escape(params.id.to_s)
              name = Infrastructure::AppleScript.escape(params.name.to_s)
              item_type = params.item_type.to_s

              Infrastructure::AppleScript.tell_document(document_body(item_type:, id:, name:))
            end
          end

          private

          def merge_params(params, kwargs)
            return params || {} if kwargs.empty?

            base = params.respond_to?(:to_h) ? params.to_h : params || {}
            base.merge(kwargs)
          end

          def missing_identifier_error
            %(return "{\\"success\\":false,\\"error\\":\\"Either id or name must be provided\\"}")
          end

          def document_body(item_type:, id:, name:)
            <<~APPLESCRIPT.chomp
              -- Find the item to remove
              #{Infrastructure::AppleScript.find_item(var: "foundItem", item_type: item_type, id: id, name: name)}
              -- If we found the item, remove it
              if foundItem is not missing value then
                set itemName to name of foundItem
                set itemId to id of foundItem as string

                -- Delete the item
                delete foundItem

                -- Return success
                return "{\\"success\\":true,\\"id\\":\\"" & itemId & "\\",\\"name\\":\\"" & itemName & "\\"}"
              else
                return "{\\"success\\":false,\\"error\\":\\"Item not found\\"}"
              end if
            APPLESCRIPT
          end
        end
      end
    end
  end
end
