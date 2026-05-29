# frozen_string_literal: true

# Opt-in integration smoke test: actually runs `osascript` against OmniFocus.
# Skipped by default; run with `INTEGRATION=1 bundle exec rspec`.
RSpec.describe OmnifocusMcp::Utils::ScriptExecution, :requires_omnifocus do
  before { described_class.reset! }
  after  { described_class.reset! }

  context "when executing JXA via osascript" do
    subject(:result) do
      described_class.execute_jxa(<<~JS)
        JSON.stringify({ greeting: "hello", n: 42 });
      JS
    end

    it "returns Result.ok with parsed JSON" do
      expect(result.ok).to eq("greeting" => "hello", "n" => 42)
    end
  end

  context "when JXA output is not valid JSON" do
    subject(:result) { described_class.execute_jxa("(() => 'not json')()") }

    it "returns Result.error with a parse failure message" do
      expect(result.error).to match(/Failed to parse script output/)
    end
  end

  context "when JXA has a syntax error" do
    subject(:result) { described_class.execute_jxa("{{invalid") }

    it "returns Result.error when osascript exits non-zero" do
      expect(result.error).to match(/osascript failed/)
    end
  end

  context "when executing OmniJS source inside OmniFocus" do
    subject(:result) do
      described_class.execute_omnifocus_source(<<~JS)
        (() => JSON.stringify({ taskCount: flattenedTasks.length }))();
      JS
    end

    it "returns Result.ok with a non-negative integer task count" do
      expect(result.ok["taskCount"]).to be_a(Integer)
      expect(result.ok["taskCount"]).to be >= 0
    end
  end

  context "when executing a bundled OmniJS script" do
    subject(:result) { described_class.execute_omnifocus_script("@listTags.js") }

    it "returns Result.ok with a tags payload" do
      expect(result.ok).to include("success" => true, "tags" => be_an(Array))
    end
  end

  context "when resolving bundled @omnifocusDump.js" do
    # Unit specs in script_execution_spec.rb verify @-shorthand resolution with a
    # mocked runner. Here we confirm the bundled file exists on disk and contains
    # expected OmniJS — we intentionally do not run the full dump (output can be huge).
    subject(:path) { described_class.resolve_script_path("@omnifocusDump.js") }

    it "finds a readable file that references flattenedTasks" do
      expect(File.exist?(path)).to be(true)
      expect(File.read(path)).to include("flattenedTasks")
    end
  end
end
