# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/database_stats"
require "omnifocus_mcp/tools/generators/query_omnifocus"
require "omnifocus_mcp/tools/generators/query_omnifocus_debug"

RSpec.describe OmnifocusMcp::Tools::Generators::QueryOmnifocus do
  describe ".generate_query_script" do
    subject(:script) { described_class.generate_query_script(entity: "tasks", filters: { task_name: "Email" }) }

    it "preserves task filter semantics" do
      expect(script).to include('.includes("email")')
    end
  end
end

RSpec.describe OmnifocusMcp::Tools::Generators::QueryOmnifocusDebug do
  describe ".generate_debug_script" do
    subject(:script) { described_class.generate_debug_script("project") }

    it "selects a project sample" do
      expect(script).to include("flattenedProjects[0]")
    end
  end
end

RSpec.describe OmnifocusMcp::Tools::Generators::DatabaseStats do
  describe ".stats_script" do
    subject(:script) { described_class.stats_script }

    it "counts active tasks" do
      expect(script).to include("activeTaskCount")
    end
  end

  describe ".changes_script" do
    subject(:script) { described_class.changes_script("2026-05-22T09:30:00Z") }

    it "embeds the since timestamp" do
      expect(script).to include('new Date("2026-05-22T09:30:00Z")')
    end
  end
end
