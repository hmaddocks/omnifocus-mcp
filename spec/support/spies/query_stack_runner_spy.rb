# frozen_string_literal: true

class QueryStackRunnerSpy
  attr_reader :sources

  def initialize(response:)
    @response = response
    @sources = []
  end

  def execute_omnifocus_source(source, args: nil)
    @sources << source
    OmnifocusMcp::Result.ok(@response)
  end
end
