# frozen_string_literal: true

module OmnifocusMcp
  module Infrastructure
    # Composable AppleScript fragments for write-side primitives.
    # rubocop:disable-next Metrics/ModuleLength
    module AppleScript
      ITEM_TYPES = %w[task project].freeze
      LOOKUP_KINDS = %i[folder project].freeze

      class << self
        # Prefix every non-empty line of `text` with `prefix`. Lines that are
        # blank or only-whitespace are passed through unchanged so the result
        # diffs cleanly.
        def indent(text:, prefix:)
          text.each_line
              .map { |line| line.strip.empty? ? line : "#{prefix}#{line}" }
              .join
        end

        # Escape `"` and `\` so `value` is safe inside an AppleScript
        # double-quoted string. CR/LF collapse to a single space.
        def escape(value)
          value.to_s
               .gsub(/["\\]/) { |m| "\\#{m}" }
               .gsub(/[\r\n]/, " ")
        end

        # Like {escape}, but keeps line breaks: CRLF and CR become LF, and
        # each LF is written as the AppleScript `\n` escape. Use for notes.
        def multiline_string(value)
          value.to_s
               .gsub(/\r\n?/, "\n")
               .gsub(/["\\]/) { |m| "\\#{m}" }
               .gsub("\n", "\\n")
        end

        # Wrap a script `body` in the standard OmniFocus front document
        # envelope used by write-side primitives. The script also defines
        # the `jsonEscape` handler, so the body can call `my jsonEscape(x)`.
        def tell_document(body)
          <<~APPLESCRIPT
            try
              tell application "OmniFocus"
                tell front document
            #{indent(text: body.chomp, prefix: "      ")}
                end tell
              end tell
            on error errorMessage
              return "{\\"success\\":false,\\"error\\":\\"" & my jsonEscape(errorMessage) & "\\"}"
            end try

            #{json_escape_handler}
          APPLESCRIPT
        end

        # Top-level AppleScript handler that escapes text for a JSON string
        # value. Backslashes are replaced first so later escapes survive.
        def json_escape_handler
          <<~'APPLESCRIPT'.chomp
            on jsonEscape(theText)
              set theText to theText as text
              set replacements to {{"\\", "\\\\"}, {"\"", "\\\""}, {linefeed, "\\n"}, {return, "\\r"}, {tab, "\\t"}}
              set savedDelimiters to AppleScript's text item delimiters
              repeat with pair in replacements
                set AppleScript's text item delimiters to item 1 of pair
                set parts to text items of theText
                set AppleScript's text item delimiters to item 2 of pair
                set theText to parts as text
              end repeat
              set AppleScript's text item delimiters to savedDelimiters
              return theText
            end jsonEscape
          APPLESCRIPT
        end

        # Find a task or project, setting `var` to the located object or
        # `missing value` when not found.
        def find_item(var:, item_type:, id:, name:)
          unless ITEM_TYPES.include?(item_type)
            raise ArgumentError, "item_type must be one of #{ITEM_TYPES.inspect}, got #{item_type.inspect}"
          end

          collection = "flattened #{item_type}"
          sections = [
            ["set #{var} to missing value"],
            id_lookup_lines(var: var, collection: collection, item_type: item_type, id: id),
            name_lookup_lines(var: var, collection: collection, item_type: item_type, name: name, fallback: !id.empty?)
          ]

          "#{sections.flatten.join("\n")}\n"
        end

        # Add the tag at `tag_path` (raw text, e.g. "Parent/Child") to
        # `item_var`, creating any missing tags along the path.
        def tag_assignment(item_var:, tag_path:)
          <<~APPLESCRIPT.chomp
            try
            #{indent(text: tag_lookup(var: "theTag", tag_path: tag_path, create: true), prefix: "  ")}
              if theTag is not missing value then add theTag to tags of #{item_var}
            on error
              -- Could not create or add tag
            end try
          APPLESCRIPT
        end

        # Resolve the tag at `tag_path` (raw text). "A/B/C" finds A anywhere,
        # then B inside A, then C inside B. Sets `var` to the tag, or to
        # `missing value` when a part is missing and `create` is false.
        def tag_lookup(var:, tag_path:, create:)
          parts = tag_path.to_s.split("/")
                          .reject(&:empty?)
                          .map { |part| escape(part) }
          return "set #{var} to missing value" if parts.empty?

          first, *rest = parts
          lines = [
            "set #{var} to missing value",
            "try",
            %(  set #{var} to first flattened tag whose name is "#{first}"),
            "end try"
          ]
          if create
            lines << %(if #{var} is missing value then set #{var} to make new tag with properties {name:"#{first}"})
          end

          rest.each { |part| lines << child_tag_lookup(var:, part:, create:) }
          lines.join("\n")
        end

        # Generate AppleScript that resolves a folder by path or simple name.
        def generate_folder_lookup_script(raw_folder_path:, var_name:, error_return_json:)
          generate_lookup_script(
            kind: :folder,
            raw_path: raw_folder_path,
            var_name: var_name,
            error_return_json: error_return_json
          )
        end

        # Generate AppleScript that resolves a project by path or simple name.
        def generate_project_lookup_script(raw_project_path:, var_name:, error_return_json:)
          generate_lookup_script(
            kind: :project,
            raw_path: raw_project_path,
            var_name: var_name,
            error_return_json: error_return_json
          )
        end

        # Unified entry point for folder/project lookup scripts.
        def generate_lookup_script(kind:, raw_path:, var_name:, error_return_json:)
          unless LOOKUP_KINDS.include?(kind)
            raise ArgumentError, "kind must be one of #{LOOKUP_KINDS.inspect}, got #{kind.inspect}"
          end

          components = raw_path.split("/")
                               .reject(&:empty?)
          return "set #{var_name} to missing value" if components.empty?

          escaped_components = components.map { |c| escape(c) }
          builder = components.length == 1 ? :simple : :nested
          send(:"#{builder}_#{kind}_lookup", var_name:, escaped_components:, error_return_json:)
        end

        private

        def child_tag_lookup(var:, part:, create:)
          parent = "#{var}Parent"
          make_line = "  if #{var} is missing value then set #{var} to " \
                      "make new tag with properties {name:\"#{part}\"} at end of tags of #{parent}"
          [
            "if #{var} is not missing value then",
            "  set #{parent} to #{var}",
            "  set #{var} to missing value",
            "  try",
            %(    set #{var} to first tag of #{parent} whose name is "#{part}"),
            "  end try",
            (make_line if create),
            "end if"
          ].compact.join("\n")
        end

        def id_lookup_lines(var:, collection:, item_type:, id:)
          return [] if id.empty?

          [
            "",
            "-- Find #{item_type} by ID",
            "try",
            %(  set #{var} to first #{collection} whose id is "#{id}"),
            "end try"
          ]
        end

        def name_lookup_lines(var:, collection:, item_type:, name:, fallback:)
          return [] if name.empty?

          if fallback
            [
              "",
              "-- Fall back to name search if id missed",
              "if #{var} is missing value then",
              "  try",
              %(    set #{var} to first #{collection} whose name is "#{name}"),
              "  end try",
              "end if"
            ]
          else
            [
              "",
              "-- Find #{item_type} by name",
              "try",
              %(  set #{var} to first #{collection} whose name is "#{name}"),
              "end try"
            ]
          end
        end

        def applescript_string_list(escaped_strings)
          escaped_strings.map { |s| %("#{s}") }.join(", ")
        end

        def simple_folder_lookup(var_name:, escaped_components:, error_return_json:)
          name = escaped_components.first
          <<~APPLESCRIPT.chomp
            set #{var_name} to missing value
            try
              set #{var_name} to first flattened folder where name = "#{name}"
            end try
            if #{var_name} is missing value then
              return "#{error_return_json}"
            end if
          APPLESCRIPT
        end

        # rubocop:disable-next Metrics/MethodLength
        def nested_folder_lookup(var_name:, escaped_components:, error_return_json:)
          leaf_name = escaped_components.last
          list_items = applescript_string_list(escaped_components)

          <<~APPLESCRIPT.chomp
            set #{var_name} to missing value
            set pathComponents to {#{list_items}}
            repeat with aFolder in (flattened folders)
              if name of aFolder = "#{leaf_name}" then
                -- Verify ancestor chain matches path
                set ancestorOk to true
                set currentItem to aFolder
                repeat with i from ((count of pathComponents) - 1) to 1 by -1
                  try
                    set currentItem to container of currentItem
                    if class of currentItem is not folder or name of currentItem is not equal to (item i of pathComponents) then
                      set ancestorOk to false
                      exit repeat
                    end if
                  on error
                    set ancestorOk to false
                    exit repeat
                  end try
                end repeat
                if ancestorOk then
                  set #{var_name} to aFolder
                  exit repeat
                end if
              end if
            end repeat
            if #{var_name} is missing value then
              return "#{error_return_json}"
            end if
          APPLESCRIPT
        end

        def simple_project_lookup(var_name:, escaped_components:, error_return_json:)
          name = escaped_components.first
          <<~APPLESCRIPT.chomp
            set #{var_name} to missing value
            try
              set #{var_name} to first flattened project whose name is "#{name}"
            end try
            if #{var_name} is missing value then
              return "#{error_return_json}"
            end if
          APPLESCRIPT
        end

        # rubocop:disable-next Metrics/MethodLength
        def nested_project_lookup(var_name:, escaped_components:, error_return_json:)
          project_name = escaped_components.last
          folder_components = escaped_components[0...-1]
          folder_items = applescript_string_list(folder_components)

          <<~APPLESCRIPT.chomp
            set #{var_name} to missing value
            set folderPath to {#{folder_items}}
            repeat with aProject in (flattened projects)
              if (name of aProject as string) = "#{project_name}" then
                -- Verify folder ancestry matches path
                set ancestorOk to true
                set currentItem to container of aProject
                repeat with i from (count of folderPath) to 1 by -1
                  try
                    if class of currentItem is not folder or name of currentItem is not equal to (item i of folderPath) then
                      set ancestorOk to false
                      exit repeat
                    end if
                    set currentItem to container of currentItem
                  on error
                    set ancestorOk to false
                    exit repeat
                  end try
                end repeat
                if ancestorOk then
                  set #{var_name} to aProject
                  exit repeat
                end if
              end if
            end repeat
            if #{var_name} is missing value then
              return "#{error_return_json}"
            end if
          APPLESCRIPT
        end
      end
    end
  end
end
