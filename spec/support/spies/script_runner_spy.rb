# frozen_string_literal: true

class ScriptRunnerSpy
  attr_reader :calls

  def initialize(response:)
    @response = response
    @calls = []
  end

  def execute_omnifocus_script(script_path, args: nil)
    @calls << [script_path, args]
    OmnifocusMcp::Result.ok(@response)
  end
end
