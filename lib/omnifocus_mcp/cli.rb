# frozen_string_literal: true

module OmnifocusMcp
  # Command-line entry point for the `omnifocus-mcp` executable.
  module Cli
    module_function

    def run(argv = ARGV)
      if version_requested?(argv)
        print_version
        exit 0
      end

      Mcp.start
    end

    def version_requested?(argv)
      argv.intersect?(OmnifocusMcp::VERSION_ARGS)
    end

    def print_version
      puts VERSION
    end
  end
end
