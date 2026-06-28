# frozen_string_literal: true

require "json"
require "open3"

module OmnifocusMcpSmokeHelpers
  BIN_PATH = File.expand_path("../bin/omnifocus-mcp", __dir__)
  GEMFILE_ENV = { "BUNDLE_GEMFILE" => File.expand_path("../Gemfile", __dir__) }.freeze

  module_function

  def run_mcp(stdin_data, *)
    Open3.capture3(GEMFILE_ENV, "bundle", "exec", BIN_PATH, *, stdin_data: stdin_data)
  end

  def json_responses(stdout)
    stdout.force_encoding(Encoding::UTF_8).each_line.filter_map do |line|
      next unless line.strip.start_with?("{")

      JSON.parse(line)
    end
  end

  def mcp_session(*messages)
    messages.map { |message| JSON.generate(message) }.join("\n") + "\n"
  end

  def initialize_request
    {
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: { name: "rspec-smoke", version: "0.0.0" }
      }
    }
  end

  def initialized_notification
    { jsonrpc: "2.0", method: "notifications/initialized" }
  end
end

RSpec.describe "omnifocus-mcp executable" do
  context "when checking the executable" do
    subject(:bin_path) { OmnifocusMcpSmokeHelpers::BIN_PATH }

    it "exists" do
      expect(File).to exist(bin_path)
    end

    it "is executable" do
      expect(File).to be_executable(bin_path)
    end
  end

  context "when invoked with a version argument" do
    let(:stdout) { stdio[0] }
    let(:stderr) { stdio[1] }
    let(:status) { stdio[2] }

    shared_examples "a version-only invocation" do
      it "prints the gem version to stdout" do
        expect(stdout).to eq("#{OmnifocusMcp::VERSION}\n")
      end

      it "exits cleanly" do
        expect(status.exitstatus).to eq(0)
      end

      it "does not start the MCP server" do
        expect(stderr).not_to include("Starting OmniFocus MCP")
      end
    end

    context "with --version" do
      subject(:stdio) { OmnifocusMcpSmokeHelpers.run_mcp("", "--version") }

      it_behaves_like "a version-only invocation"
    end

    context "with -v" do
      subject(:stdio) { OmnifocusMcpSmokeHelpers.run_mcp("", "-v") }

      it_behaves_like "a version-only invocation"
    end

    context "with version" do
      subject(:stdio) { OmnifocusMcpSmokeHelpers.run_mcp("", "version") }

      it_behaves_like "a version-only invocation"
    end
  end

  context "when sent an MCP initialize request over stdio" do
    subject(:stdio) { OmnifocusMcpSmokeHelpers.run_mcp(stdin_data) }

    let(:stdin_data) { OmnifocusMcpSmokeHelpers.mcp_session(OmnifocusMcpSmokeHelpers.initialize_request) }
    let(:stdout) { stdio[0] }
    let(:stderr) { stdio[1] }
    let(:status) { stdio[2] }
    let(:response) { OmnifocusMcpSmokeHelpers.json_responses(stdout).first }

    it "exits cleanly when stdin closes" do
      expect(status.exitstatus).to eq(0), "stderr was: #{stderr}"
    end

    it "returns a JSON response on stdout" do
      expect(response).not_to be_nil, "expected JSON response on stdout, got: #{stdout.inspect}"
    end

    it "returns a JSON-RPC 2.0 response" do
      expect(response["jsonrpc"]).to eq("2.0")
    end

    it "returns the initialize request id" do
      expect(response["id"]).to eq(1)
    end

    it "returns the server name" do
      expect(response.dig("result", "serverInfo", "name")).to eq(OmnifocusMcp::Mcp.server_name)
    end

    it "returns the server version" do
      expect(response.dig("result", "serverInfo", "version")).to eq(OmnifocusMcp::Mcp.server_version)
    end

    it "logs the server version to stderr on startup" do
      expect(stderr).to include("Starting OmniFocus MCP v#{OmnifocusMcp::VERSION}")
    end
  end

  context "when listing tools over stdio" do
    subject(:stdio) { OmnifocusMcpSmokeHelpers.run_mcp(stdin_data) }

    let(:stdin_data) do
      OmnifocusMcpSmokeHelpers.mcp_session(
        OmnifocusMcpSmokeHelpers.initialize_request,
        OmnifocusMcpSmokeHelpers.initialized_notification,
        { jsonrpc: "2.0", id: 2, method: "tools/list", params: {} }
      )
    end
    let(:stdout) { stdio[0] }
    let(:responses) { OmnifocusMcpSmokeHelpers.json_responses(stdout) }
    let(:tool_names) { responses.last.dig("result", "tools").map { |tool| tool["name"] } }
    let(:expected_tool_names) { OmnifocusMcp::Mcp.build_server.tools.keys }

    it "returns the registered tool names" do
      expect(tool_names).to match_array(expected_tool_names)
    end
  end

  context "when listing resources over stdio" do
    subject(:stdio) { OmnifocusMcpSmokeHelpers.run_mcp(stdin_data) }

    let(:stdin_data) do
      OmnifocusMcpSmokeHelpers.mcp_session(
        OmnifocusMcpSmokeHelpers.initialize_request,
        OmnifocusMcpSmokeHelpers.initialized_notification,
        { jsonrpc: "2.0", id: 3, method: "resources/list", params: {} }
      )
    end
    let(:stdout) { stdio[0] }
    let(:responses) { OmnifocusMcpSmokeHelpers.json_responses(stdout) }
    let(:resource_names) { responses.last.dig("result", "resources").map { |resource| resource["name"] } }
    let(:fixed_names) { OmnifocusMcp::Mcp.build_server.resources.reject(&:templated?).map(&:resource_name) }

    it "returns the fixed resource names" do
      expect(resource_names).to match_array(fixed_names)
    end
  end

  context "when stdin contains invalid JSON" do
    subject(:stdio) { OmnifocusMcpSmokeHelpers.run_mcp("not json\n") }

    let(:stdout) { stdio[0] }
    let(:status) { stdio[2] }
    let(:response) { OmnifocusMcpSmokeHelpers.json_responses(stdout).first }

    it "exits cleanly" do
      expect(status.exitstatus).to eq(0)
    end

    it "returns an invalid request error code" do
      expect(response.dig("error", "code")).to eq(-32_600)
    end

    it "returns an invalid request error message" do
      expect(response.dig("error", "message")).to eq("Invalid Request")
    end

    it "uses a numeric id instead of null for Cursor JSON-RPC validation" do
      expect(response["id"]).to eq(0)
    end
  end

  context "when stdin contains a blank line" do
    subject(:stdio) { OmnifocusMcpSmokeHelpers.run_mcp("\n") }

    let(:stdout) { stdio[0] }
    let(:status) { stdio[2] }

    it "exits cleanly" do
      expect(status.exitstatus).to eq(0)
    end

    it "does not emit a JSON-RPC error" do
      expect(stdout).to be_empty
    end
  end

  context "when stdin contains UTF-8 in the JSON payload" do
    subject(:stdio) { OmnifocusMcpSmokeHelpers.run_mcp(stdin_data) }

    let(:stdin_data) do
      request = {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {
          protocolVersion: "2024-11-05",
          capabilities: {},
          clientInfo: { name: "café", version: "0.0.0" }
        }
      }
      OmnifocusMcpSmokeHelpers.mcp_session(request)
    end
    let(:stdout) { stdio[0] }
    let(:status) { stdio[2] }
    let(:response) { OmnifocusMcpSmokeHelpers.json_responses(stdout).first }

    it "exits cleanly" do
      expect(status.exitstatus).to eq(0)
    end

    it "returns a JSON-RPC response" do
      expect(response["jsonrpc"]).to eq("2.0")
    end
  end
end
