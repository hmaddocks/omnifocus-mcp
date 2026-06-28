# frozen_string_literal: true

RSpec.describe OmnifocusMcp::Mcp do
  subject(:server) { described_class.build_server(logger:) }

  let(:logger) { FastMcp::Logger.new }
  let(:expected_tools) do
    [
      OmnifocusMcp::Tools::Definitions::AddOmniFocusTaskTool,
      OmnifocusMcp::Tools::Definitions::AddProjectTool,
      OmnifocusMcp::Tools::Definitions::RemoveItemTool,
      OmnifocusMcp::Tools::Definitions::EditItemTool,
      OmnifocusMcp::Tools::Definitions::BatchAddItemsTool,
      OmnifocusMcp::Tools::Definitions::BatchRemoveItemsTool,
      OmnifocusMcp::Tools::Definitions::QueryOmnifocusTool,
      OmnifocusMcp::Tools::Definitions::ListPerspectivesTool,
      OmnifocusMcp::Tools::Definitions::GetPerspectiveViewTool,
      OmnifocusMcp::Tools::Definitions::ListTagsTool
    ]
  end
  let(:expected_resources) do
    [
      OmnifocusMcp::Resources::InboxResource,
      OmnifocusMcp::Resources::TodayResource,
      OmnifocusMcp::Resources::FlaggedResource,
      OmnifocusMcp::Resources::StatsResource,
      OmnifocusMcp::Resources::ProjectResource,
      OmnifocusMcp::Resources::PerspectiveResource
    ]
  end

  describe ".server_name" do
    it "returns the MCP server name" do
      expect(described_class.server_name).to eq("OmniFocus MCP")
    end
  end

  describe ".server_version" do
    it "returns the gem version" do
      expect(described_class.server_version).to eq(OmnifocusMcp::VERSION)
    end
  end

  describe ".start" do
    subject(:start) { described_class.start }

    let(:server) { instance_double(FastMcp::Server, start: nil) }

    before do
      allow(described_class).to receive(:build_server).and_return(server)
    end

    it "logs the server version to stderr" do
      expect { start }.to output(/Starting OmniFocus MCP v#{Regexp.escape(OmnifocusMcp::VERSION)}/o).to_stderr
    end

    it "starts the built server" do
      start

      expect(server).to have_received(:start)
    end
  end

  describe ".build_server" do
    context "when configuring the FastMcp server" do
      it "returns a FastMcp::Server" do
        expect(server).to be_a(FastMcp::Server)
      end

      it "sets the expected name and version" do
        expect([server.name, server.version]).to eq([described_class.server_name, described_class.server_version])
      end

      it "uses the injected logger" do
        expect(server.logger).to be(logger)
      end
    end

    context "when registering tools" do
      it "registers every expected tool" do
        expect(server.tools.keys).to match_array(expected_tools.map(&:tool_name))
      end

      it "maps each registered tool name to its tool class" do
        expect(server.tools).to include(expected_tools.to_h { |tool_class| [tool_class.tool_name, tool_class] })
      end
    end

    context "when registering resources" do
      it "registers every expected resource" do
        expect(server.resources.map(&:resource_name)).to match_array(expected_resources.map(&:resource_name))
      end

      it "registers each resource class" do
        expect(server.resources).to include(*expected_resources)
      end

      it "registers the expected fixed and templated resources" do
        expect([server.resources.count(&:non_templated?), server.resources.count(&:templated?)])
          .to eq([expected_resources.count(&:non_templated?), expected_resources.count(&:templated?)])
      end
    end
  end

  describe "deprecated Server bootstrap" do
    it "does not define OmnifocusMcp::Server" do
      expect(OmnifocusMcp.const_defined?(:Server, false)).to be false
    end

    it "does not ship lib/omnifocus_mcp/server.rb" do
      server_file = File.expand_path("../../lib/omnifocus_mcp/server.rb", __dir__)

      expect(File).not_to exist(server_file)
    end
  end
end
