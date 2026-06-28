# frozen_string_literal: true

require "debug"

require "omnifocus_mcp"
require_relative "integration/helpers"

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |c|
    c.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.warnings = false
  config.order = :random
  Kernel.srand config.seed

  config.before(:context, :requires_omnifocus) do
    OmnifocusMcp::IntegrationHelpers.assert_omnifocus_running!
  rescue OmnifocusMcp::IntegrationHelpers::OmniFocusAccessError => e
    skip e.message
  end

  # Use documentation format for individual files, progress for full suite
  # Individual file: bundle exec rspec spec/some_spec.rb
  # Full suite: bundle exec rspec (or multiple files)
  config.default_formatter = config.files_to_run.one? ? "documentation" : "progress"

  # Integration specs hit the real OmniFocus app; opt in with INTEGRATION=1.
  config.filter_run_excluding requires_omnifocus: true unless ENV["INTEGRATION"] == "1"
end
