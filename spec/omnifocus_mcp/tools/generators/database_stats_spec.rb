# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/database_stats"

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

    it "escapes special characters in the since timestamp" do
      malicious_input = "2026-05-22T09:30:00Z\"); malicious();//"
      script = described_class.changes_script(malicious_input)

      expect(script).to include('new Date("2026-05-22T09:30:00Z\"); malicious();//")')
    end
  end
end
