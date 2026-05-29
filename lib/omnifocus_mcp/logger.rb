# frozen_string_literal: true

require "logger"

module OmnifocusMcp
  module_function

  # Application-wide logger writing to the current `$stderr`.
  #
  # Rebuilds when `$stderr` changes so test helpers that redirect stderr
  # (RSpec's `output.to_stderr`, silencing helpers) still capture log lines.
  def logger
    reset_logger_if_stderr_changed
    @logger ||= build_logger
  end

  def reset_logger!
    @logger = nil
    @logger_stderr = nil
  end

  def build_logger
    Logger.new($stderr, progname: "omnifocus_mcp").tap { |log| log.level = Logger::WARN }
  end
  private :build_logger

  def reset_logger_if_stderr_changed
    return if @logger_stderr.equal?($stderr)

    @logger = nil
    @logger_stderr = $stderr
  end
  private :reset_logger_if_stderr_changed
end
