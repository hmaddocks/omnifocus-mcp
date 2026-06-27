# frozen_string_literal: true

RSpec.describe OmnifocusMcp::Cli do
  describe ".version_requested?" do
    it "returns true for --version" do
      expect(described_class.version_requested?(["--version"])).to be true
    end

    it "returns true for -v" do
      expect(described_class.version_requested?(["-v"])).to be true
    end

    it "returns true for version" do
      expect(described_class.version_requested?(["version"])).to be true
    end

    it "returns false when no version flag is present" do
      expect(described_class.version_requested?([])).to be false
    end
  end

  describe ".print_version" do
    subject(:print_version) { described_class.print_version }

    it "prints the gem version to stdout" do
      expect { print_version }.to output("#{OmnifocusMcp::VERSION}\n").to_stdout
    end
  end

  describe ".run" do
    before do
      allow(Kernel).to receive(:exit)
    end

    context "when --version is passed" do
      subject(:run) { described_class.run(["--version"]) }

      it "prints the gem version" do
        expect { run }.to output("#{OmnifocusMcp::VERSION}\n").to_stdout
      end

      it "exits with status 0" do
        run

        expect(Kernel).to have_received(:exit).with(0)
      end

      it "does not start the MCP server" do
        allow(OmnifocusMcp::Mcp).to receive(:start)

        run

        expect(OmnifocusMcp::Mcp).not_to have_received(:start)
      end
    end

    context "when -v is passed" do
      subject(:run) { described_class.run(["-v"]) }

      it "prints the gem version" do
        expect { run }.to output("#{OmnifocusMcp::VERSION}\n").to_stdout
      end

      it "exits with status 0" do
        run

        expect(Kernel).to have_received(:exit).with(0)
      end
    end
  end
end
