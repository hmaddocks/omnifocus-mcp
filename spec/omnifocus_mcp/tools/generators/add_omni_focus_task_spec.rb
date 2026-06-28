# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/add_omni_focus_task"

RSpec.describe OmnifocusMcp::Tools::Generators::AddOmniFocusTask do
  describe ".generate_apple_script" do
    subject(:script) { described_class.generate_apple_script(name: "Buy milk") }

    it "creates an inbox task" do
      expect(script).to include(%(make new inbox task with properties {name:"Buy milk"}))
    end
  end

  describe ".generate_bulk_apple_script" do
    subject(:script) { described_class.generate_bulk_apple_script([{ name: "A" }, { name: "B" }]) }

    it "records bulk task ids" do
      expect(script).to include("set end of bulkTaskIds to taskId")
    end
  end
end
