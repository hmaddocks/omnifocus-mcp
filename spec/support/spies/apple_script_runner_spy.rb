# frozen_string_literal: true

class AppleScriptRunnerSpy
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
