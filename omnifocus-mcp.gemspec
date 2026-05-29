# frozen_string_literal: true

require_relative "lib/omnifocus_mcp/version"

Gem::Specification.new do |spec|
  spec.name = "omnifocus-mcp"
  spec.version = OmnifocusMcp::VERSION
  spec.authors = ["Henry"]
  spec.summary = "MCP server bridging LLM clients to OmniFocus on macOS."
  spec.description = "MCP server for OmniFocus on macOS, built on the fast-mcp gem. " \
                     "Exposes OmniFocus tasks, projects, perspectives, and tags to MCP clients over stdio."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.files = Dir[
    "lib/**/*.rb",
    "lib/**/*.js",
    "bin/*",
    "README.md",
    "LICENSE*"
  ]
  spec.bindir = "bin"
  spec.executables = ["omnifocus-mcp"]
  spec.require_paths = ["lib"]

  spec.add_dependency "fast-mcp", "~> 1.6"

  spec.metadata["rubygems_mfa_required"] = "true"
end
