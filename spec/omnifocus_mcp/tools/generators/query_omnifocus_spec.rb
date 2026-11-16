# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/query_omnifocus"

RSpec.describe OmnifocusMcp::Tools::Generators::QueryOmnifocus do
  describe ".generate_query_script" do
    subject(:script) { described_class.generate_query_script(entity: "tasks", filters: filters) }

    let(:filters) { { task_name: "Email" } }

    it "preserves task filter semantics" do
      expect(script).to include('.includes("email")')
    end

    it "skips project root tasks" do
      expect(script).to include("items = flattenedTasks.filter(task => task.project === null);")
    end

    context "with hasNote filter" do
      let(:filters) { { has_note: false } }

      it "compares a boolean note check" do
        expect(script).to include('const hasNote = (item.note || "").trim().length > 0;')
      end
    end
  end
end
