# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/query_omnifocus"

RSpec.describe OmnifocusMcp::Tools::Generators::QueryOmnifocus do
  describe ".generate_query_script" do
    subject(:script) { described_class.generate_query_script(entity: "tasks", filters: { task_name: "Email" }) }

    it "preserves task filter semantics" do
      expect(script).to include('.includes("email")')
    end
  end
end
