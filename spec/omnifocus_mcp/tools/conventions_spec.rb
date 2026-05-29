# frozen_string_literal: true

RSpec.describe "tool layer conventions" do
  subject(:tools_root) { File.expand_path("../../../lib/omnifocus_mcp/tools", __dir__) }

  describe "module singletons" do
    it "uses class-level methods instead of module_function" do
      offenders = Dir.glob("#{tools_root}/**/*.rb").select do |path|
        File.read(path, mode: "r:utf-8").match?(/^\s*module_function\b/)
      end

      expect(offenders).to be_empty
    end
  end

  describe "operation classes" do
    it "uses the explicit class-level call entry point" do
      operation_files = Dir.glob("#{tools_root}/operations/**/*.rb")
                           .reject { |path| File.basename(path).start_with?(".") }
      operation_class_files = operation_files.select do |path|
        source = File.read(path, mode: "r:utf-8")
        source.match?(/^\s*class\s+/) && source.match?(/^\s*def call\b/)
      end
      offenders = operation_class_files.reject do |path|
        source = File.read(path, mode: "r:utf-8")
        source.match?(/^\s*def self\.call\b/) || source.match?(/^\s*class << self\b.*?^\s*def call\b/m)
      end

      expect(offenders).to be_empty
    end
  end

  describe "tool reply envelopes" do
    it "routes tool definition replies through McpEnvelope::ToolReply" do
      definition_files = Dir.glob("#{tools_root}/definitions/*_tool.rb")
      offenders = definition_files.select do |path|
        source = File.read(path, mode: "r:utf-8")
        source.match?(/text_(?:result|error)\(/) || !source.include?("McpEnvelope::ToolReply")
      end

      expect(offenders).to be_empty
    end
  end

  describe "tool operation injection" do
    it "does not use primitive class hooks in tool definitions" do
      definition_files = Dir.glob("#{tools_root}/definitions/*_tool.rb")
      offenders = definition_files.select do |path|
        source = File.read(path, mode: "r:utf-8")
        source.match?(/\bself\.primitive\b|attr_writer\s+:primitive\b/)
      end

      expect(offenders).to be_empty
    end
  end

  describe "tool definition support modules" do
    it "does not reference the generic Helpers module from production code" do
      production_files = Dir.glob("#{tools_root}/**/*.rb")
                            .reject { |path| File.basename(path) == "helpers.rb" }
      offenders = production_files.select do |path|
        source = File.read(path, mode: "r:utf-8")
        source.match?(/\bDefinitions::Helpers\b|\bHelpers::|\bHelpers\./)
      end

      expect(offenders).to be_empty
    end
  end

  describe "deprecated primitive facades" do
    it "does not ship tools/primitives files" do
      primitive_files = Dir.glob("#{tools_root}/primitives/**/*.rb")

      expect(primitive_files).to be_empty
    end

    it "does not reference the deprecated Primitives namespace from production code" do
      offenders = Dir.glob("#{tools_root}/**/*.rb").select do |path|
        File.read(path, mode: "r:utf-8").match?(%r{\bPrimitives::|Tools::Primitives\b|tools/primitives})
      end

      expect(offenders).to be_empty
    end
  end
end
