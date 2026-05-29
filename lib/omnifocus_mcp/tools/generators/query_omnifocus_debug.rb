# frozen_string_literal: true

require_relative "../../result"
require_relative "../../infrastructure/script_runner"

module OmnifocusMcp
  module Tools
    module Generators
      # Debug variant of `QueryOmnifocus` that returns raw field information
      # for a single sample item. Useful for understanding what fields are
      # actually exposed by the OmniFocus JS API.
      class QueryOmnifocusDebug
        ENTITIES = %w[task project folder].freeze
        private_constant :ENTITIES

        # @param entity ['task'|'project'|'folder']
        # @return [OmnifocusMcp::Result] +ok+ carries the parsed JSON Hash from the script
        class << self
          def call(entity)
            require_relative "../operations/query_omnifocus_debug"

            Operations::QueryOmnifocusDebug.call(entity)
          end

          # Build the OmniJS debug script for the given entity.
          # @param entity [String] one of {ENTITIES}
          def generate_debug_script(entity)
            <<~JS
              (() => {
                try {
                  let item;
                  const entityType = "#{entity}";

                  if (entityType === "task") {
                    item = flattenedTasks[0];
                  } else if (entityType === "project") {
                    item = flattenedProjects[0];
                  } else if (entityType === "folder") {
                    item = flattenedFolders[0];
                  }

                  if (!item) {
                    return JSON.stringify({ error: "No items found" });
                  }

                  const properties = {};
                  const skipProps = ['constructor', 'toString', 'valueOf'];

                  for (let prop in item) {
                    if (skipProps.includes(prop)) continue;

                    try {
                      const value = item[prop];
                      const valueType = typeof value;

                      if (value === null) {
                        properties[prop] = { type: 'null', value: null };
                      } else if (value === undefined) {
                        properties[prop] = { type: 'undefined', value: undefined };
                      } else if (valueType === 'function') {
                        properties[prop] = { type: 'function', value: '[Function]' };
                      } else if (value instanceof Date) {
                        properties[prop] = { type: 'Date', value: value.toISOString() };
                      } else if (Array.isArray(value)) {
                        properties[prop] = {
                          type: 'Array',
                          length: value.length,
                          sample: value.length > 0 ? value[0] : null
                        };
                      } else if (valueType === 'object') {
                        if (value.id && value.id.primaryKey) {
                          properties[prop] = {
                            type: 'OFObject',
                            id: value.id.primaryKey,
                            name: value.name || null
                          };
                        } else {
                          properties[prop] = { type: 'object', keys: Object.keys(value) };
                        }
                      } else {
                        properties[prop] = { type: valueType, value: value };
                      }
                    } catch (e) {
                      properties[prop] = { type: 'error', error: e.toString() };
                    }
                  }

                  const checkProps = [
                    'id', 'name', 'note', 'flagged', 'dueDate', 'deferDate',
                    'estimatedMinutes', 'modificationDate', 'creationDate',
                    'completionDate', 'taskStatus', 'status', 'tasks', 'projects',
                    'containingProject', 'parentFolder', 'parent', 'children'
                  ];

                  const expectedProps = {};
                  checkProps.forEach(prop => {
                    try {
                      const value = item[prop];
                      if (value !== undefined) {
                        if (value && value.id && value.id.primaryKey) {
                          expectedProps[prop] = {
                            exists: true,
                            type: 'OFObject',
                            id: value.id.primaryKey
                          };
                        } else if (value instanceof Date) {
                          expectedProps[prop] = {
                            exists: true,
                            type: 'Date',
                            value: value.toISOString()
                          };
                        } else if (Array.isArray(value)) {
                          expectedProps[prop] = {
                            exists: true,
                            type: 'Array',
                            length: value.length
                          };
                        } else {
                          expectedProps[prop] = {
                            exists: true,
                            type: typeof value,
                            value: value
                          };
                        }
                      } else {
                        expectedProps[prop] = { exists: false };
                      }
                    } catch (e) {
                      expectedProps[prop] = { exists: false, error: e.toString() };
                    }
                  });

                  return JSON.stringify({
                    entityType: entityType,
                    itemName: item.name || 'Unnamed',
                    allProperties: properties,
                    expectedProperties: expectedProps
                  }, null, 2);

                } catch (error) {
                  return JSON.stringify({ error: error.toString() });
                }
              })();
            JS
          end

          private

          def classify_response(response)
            shape = response.is_a?(Hash) ? response.transform_keys(&:to_sym) : nil

            case shape
            in { error: String => msg }
              OmnifocusMcp::Result.error(msg)
            in Hash
              OmnifocusMcp::Result.ok(response)
            in nil
              OmnifocusMcp::Result.error("Unexpected response from query_omnifocus_debug: #{response.inspect}")
            end
          end

          def unknown_entity_message(entity)
            "Unknown entity: #{entity.inspect}. Must be one of #{ENTITIES.join(", ")}"
          end
        end
      end
    end
  end
end
