# frozen_string_literal: true

require_relative "lib/omnifocus_mcp/version"

Gem::Specification.new do |spec|
  spec.name = "omnifocus_mcp"
  spec.version = OmnifocusMcp::VERSION
  spec.authors = ["Henry Maddocks"]
  spec.email = ["hmaddocks@me.com"]

  spec.summary = "MCP server bridging LLM clients to OmniFocus on macOS."
  spec.description = "MCP server for OmniFocus on macOS, built on the fast-mcp gem. " \
                     "Exposes OmniFocus tasks, projects, perspectives, and tags to MCP clients over stdio."
  spec.homepage = "https://github.com/hmaddocks/omnifocus-mcp"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"
  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/hmaddocks/omnifocus-mcp"
  spec.metadata["changelog_uri"] = "https://github.com/hmaddocks/omnifocus-mcp/CHANGELOG.md"

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .rubocop.yml])
    end
  end
  spec.bindir = "bin"
  spec.executables = ["omnifocus-mcp"]
  spec.require_paths = ["lib"]

  spec.add_dependency "fast-mcp", "~> 1.6"

end
