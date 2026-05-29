# frozen_string_literal: true

RSpec.describe "OmnifocusMcp namespace scaffolding" do
  subject(:root) { File.expand_path("../../lib/omnifocus_mcp", __dir__) }

  let(:expected_namespaces) do
    [
      OmnifocusMcp::Infrastructure,
      OmnifocusMcp::Parsers,
      OmnifocusMcp::Tools::Generators,
      OmnifocusMcp::Tools::Operations,
      OmnifocusMcp::Tools::Presenters
    ]
  end

  let(:expected_directories) do
    %w[
      infrastructure
      parsers
      tools/generators
      tools/operations
      tools/presenters
    ]
  end

  it "loads the empty namespace modules" do
    expect(expected_namespaces).to all(be_a(Module))
  end

  it "creates directories for future extracted classes" do
    paths = expected_directories.map { |directory| File.join(root, directory) }

    expect(paths.all? { |path| File.directory?(path) }).to be(true)
  end
end
