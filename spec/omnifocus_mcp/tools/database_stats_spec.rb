# frozen_string_literal: true

require "omnifocus_mcp/tools/database_stats"

RSpec.describe OmnifocusMcp::Tools::DatabaseStats do
  let(:success_status) { instance_double(Process::Status, success?: true) }
  let(:failure_status) { instance_double(Process::Status, success?: false, exitstatus: 1) }

  before { OmnifocusMcp::Utils::ScriptExecution.reset! }

  after  { OmnifocusMcp::Utils::ScriptExecution.reset! }

  describe ".get_database_stats" do
    context "when the OmniJS script succeeds" do
      subject(:result) do
        OmnifocusMcp::Utils::ScriptExecution.runner = lambda { |*_argv|
          [JSON.generate(stats_payload), "", success_status]
        }

        described_class.get_database_stats
      end

      let(:stats_payload) do
        {
          "taskCount" => 12,
          "activeTaskCount" => 5,
          "projectCount" => 3,
          "activeProjectCount" => 2,
          "folderCount" => 1,
          "tagCount" => 4,
          "overdueCount" => 1,
          "nextActionCount" => 2,
          "flaggedCount" => 3,
          "inboxCount" => 6,
          "lastModified" => "2026-05-23T00:00:00Z"
        }
      end

      it "returns Result.ok with the parsed stats hash" do
        expect(result.ok).to eq(stats_payload)
      end

      it "includes every documented stats field" do
        expect(result.ok.keys).to contain_exactly(
          "taskCount",
          "activeTaskCount",
          "projectCount",
          "activeProjectCount",
          "folderCount",
          "tagCount",
          "overdueCount",
          "nextActionCount",
          "flaggedCount",
          "inboxCount",
          "lastModified"
        )
      end
    end

    context "when the OmniJS script returns an error envelope" do
      subject(:result) do
        OmnifocusMcp::Utils::ScriptExecution.runner = lambda { |*_argv|
          [JSON.generate(error: "boom"), "", success_status]
        }

        described_class.get_database_stats
      end

      it "returns Result.error with the script error message" do
        expect(result.error).to eq("boom")
      end
    end

    context "when ScriptExecution fails" do
      subject(:result) do
        OmnifocusMcp::Utils::ScriptExecution.runner = lambda { |*_argv|
          ["not json", "osascript failed", failure_status]
        }

        described_class.get_database_stats
      end

      it "returns Result.error" do
        expect(result.error).to match(/Failed to parse script output|osascript failed/)
      end
    end
  end

  describe ".get_changes_since" do
    let(:changes_payload) do
      {
        "newTasks" => [],
        "updatedTasks" => [],
        "completedTasks" => [],
        "newProjects" => [],
        "updatedProjects" => []
      }
    end

    let(:captured_script) { +"" }

    context "when the OmniJS script succeeds with a Time since value" do
      subject(:result) do
        OmnifocusMcp::Utils::ScriptExecution.runner = lambda { |*argv|
          captured_script.replace(File.read(argv.last))
          [JSON.generate(changes_payload), "", success_status]
        }

        described_class.get_changes_since(since)
      end

      let(:since) { Time.utc(2026, 5, 22, 9, 30) }

      it "embeds the ISO timestamp in the generated script" do
        result

        expect(captured_script).to include('new Date("2026-05-22T09:30:00Z")')
      end

      it "returns Result.ok with every changes collection" do
        expect(result.ok).to eq(changes_payload)
      end
    end

    context "when since is an ISO string" do
      subject(:result) do
        OmnifocusMcp::Utils::ScriptExecution.runner = lambda { |*argv|
          captured_script.replace(File.read(argv.last))
          [JSON.generate(changes_payload), "", success_status]
        }

        described_class.get_changes_since("2026-05-22T09:30:00Z")
      end

      it "embeds the string timestamp in the generated script" do
        result

        expect(captured_script).to include('new Date("2026-05-22T09:30:00Z")')
      end

      it "returns Result.ok" do
        expect(result).to be_ok
      end
    end

    context "when building the changes script" do
      it "escapes special characters in a string since timestamp" do
        malicious_input = "2026-05-22T09:30:00Z\"); malicious();//"
        script = described_class.changes_script(malicious_input)

        expect(script).to include('new Date("2026-05-22T09:30:00Z\"); malicious();//")')
      end
    end

    context "when the OmniJS script returns an error envelope" do
      subject(:result) do
        OmnifocusMcp::Utils::ScriptExecution.runner = lambda { |*_argv|
          [JSON.generate(error: "boom"), "", success_status]
        }

        described_class.get_changes_since(Time.utc(2026, 5, 22))
      end

      it "returns Result.error with the script error message" do
        expect(result.error).to eq("boom")
      end
    end

    context "when ScriptExecution fails" do
      subject(:result) do
        OmnifocusMcp::Utils::ScriptExecution.runner = lambda { |*_argv|
          ["not json", "osascript failed", failure_status]
        }

        described_class.get_changes_since(Time.utc(2026, 5, 22))
      end

      it "returns Result.error" do
        expect(result.error).to match(/Failed to parse script output|osascript failed/)
      end
    end
  end
end
