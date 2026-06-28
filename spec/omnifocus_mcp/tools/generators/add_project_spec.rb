# frozen_string_literal: true

require "omnifocus_mcp/tools/generators/add_project"

RSpec.describe OmnifocusMcp::Tools::Generators::AddProject do
  describe ".generate_apple_script" do
    subject(:script) { described_class.generate_apple_script(name: "Test Project", folder_name: "Work") }

    it "creates the project" do
      expect(script).to include(%(make new project with properties {name:"Test Project"}))
    end

    it "looks up the destination folder" do
      expect(script).to include(%(first flattened folder where name = "Work"))
    end
  end
end
