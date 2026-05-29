# frozen_string_literal: true

require "omnifocus_mcp/tools/operations/add_omnifocus_task"
require "omnifocus_mcp/tools/operations/edit_item"

RSpec.describe OmnifocusMcp::Tools::Operations::AddOmniFocusTask do
  describe ".call" do
    subject(:result) { described_class.call({ name: "Buy milk" }, script_runner:) }

    let(:script_runner) do
      TaskEditRunnerSpy.new(stdout: '{"success":true,"taskId":"abc","placement":"inbox"}')
    end

    it "returns the created task id" do
      expect(result.ok.task_id).to eq("abc")
    end

    it "runs generated AppleScript through the injected runner" do
      result
      expect(script_runner.scripts.first).to include(%(make new inbox task with properties {name:"Buy milk"}))
    end
  end
end

RSpec.describe OmnifocusMcp::Tools::Operations::EditItem do
  describe ".call" do
    subject(:result) { described_class.call({ item_type: "task", name: "Task", new_name: "Updated" }, script_runner:) }

    let(:script_runner) do
      TaskEditRunnerSpy.new(stdout: '{"success":true,"id":"abc","name":"Task","changedProperties":"name"}')
    end

    it "returns the changed properties" do
      expect(result.ok.changed_properties).to eq("name")
    end

    it "runs generated AppleScript through the injected runner" do
      result
      expect(script_runner.scripts.first).to include(%(set name of foundItem to "Updated"))
    end
  end
end

class TaskEditRunnerSpy
  attr_reader :scripts

  def initialize(stdout:, stderr: "", status: nil)
    @stdout = stdout
    @stderr = stderr
    @status = status || SuccessfulStatus.new
    @scripts = []
  end

  def execute_applescript(script)
    @scripts << script
    [@stdout, @stderr, @status]
  end

  class SuccessfulStatus
    def success? = true
    def exitstatus = 0
  end
end
