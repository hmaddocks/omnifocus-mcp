# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/query_omnifocus_debug"

RSpec.describe OmnifocusMcp::Tools::Generators::QueryOmnifocusDebug do
  describe ".generate_debug_script" do
    subject(:script) { described_class.generate_debug_script("project") }

    it "selects a project sample" do
      expect(script).to include("flattenedProjects[0]")
    end
  end
end
