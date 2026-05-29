# frozen_string_literal: true

module OmnifocusMcp
  module Infrastructure
    # Escapes Ruby strings before embedding them into generated JavaScript/JXA.
    module JsEmbed
      DOUBLE_QUOTED_STRING_ESCAPES = {
        "\\" => "\\\\",
        '"' => '\\"',
        "\n" => "\\n",
        "\r" => "\\r"
      }.freeze
      private_constant :DOUBLE_QUOTED_STRING_ESCAPES

      DOUBLE_QUOTED_STRING_ESCAPE_REGEX = /[\\"\n\r]/
      private_constant :DOUBLE_QUOTED_STRING_ESCAPE_REGEX

      TEMPLATE_LITERAL_ESCAPES = {
        "\\" => "\\\\",
        "`" => "\\`",
        "$" => "\\$"
      }.freeze
      private_constant :TEMPLATE_LITERAL_ESCAPES

      TEMPLATE_LITERAL_ESCAPE_REGEX = /[\\`$]/
      private_constant :TEMPLATE_LITERAL_ESCAPE_REGEX

      class << self
        def double_quoted_string(value)
          value.to_s.gsub(DOUBLE_QUOTED_STRING_ESCAPE_REGEX, DOUBLE_QUOTED_STRING_ESCAPES)
        end

        def template_literal(value)
          value.to_s.gsub(TEMPLATE_LITERAL_ESCAPE_REGEX, TEMPLATE_LITERAL_ESCAPES)
        end
      end
    end
  end
end
