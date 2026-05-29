# frozen_string_literal: true

require "omnifocus_mcp/tools/definitions/date_formatter"

RSpec.describe OmnifocusMcp::Tools::Definitions::DateFormatter do
  describe ".format_date" do
    let(:iso_date) { "2026-05-23" }
    let(:iso_timestamp) { "2026-05-23T15:00:00Z" }

    context "with style: :locale" do
      it "renders ISO dates as M/D/YYYY without zero padding" do
        expect(described_class.format_date(iso_date, style: :locale)).to eq("5/23/2026")
      end

      it "returns empty string for nil" do
        expect(described_class.format_date(nil, style: :locale)).to eq("")
      end

      it "returns empty string for empty input" do
        expect(described_class.format_date("", style: :locale)).to eq("")
      end

      it "returns empty string for unparseable input" do
        expect(described_class.format_date("not a date", style: :locale)).to eq("")
      end
    end

    context "with style: :compact" do
      it "renders ISO dates as M/D" do
        expect(described_class.format_date(iso_date, style: :compact)).to eq("5/23")
      end

      it "returns empty string for nil" do
        expect(described_class.format_date(nil, style: :compact)).to eq("")
      end

      it "returns empty string for empty input" do
        expect(described_class.format_date("", style: :compact)).to eq("")
      end

      it "returns empty string for unparseable input" do
        expect(described_class.format_date("not a date", style: :compact)).to eq("")
      end
    end

    context "with style: :iso" do
      it "passes ISO dates through" do
        expect(described_class.format_date(iso_date, style: :iso)).to eq("2026-05-23")
      end

      it "extracts date prefix from full ISO timestamps" do
        expect(described_class.format_date(iso_timestamp, style: :iso)).to eq("2026-05-23")
      end

      it "returns empty string for nil" do
        expect(described_class.format_date(nil, style: :iso)).to eq("")
      end

      it "returns empty string for empty input" do
        expect(described_class.format_date("", style: :iso)).to eq("")
      end

      it "returns nil for unparseable input" do
        expect(described_class.format_date("not-a-real-date", style: :iso)).to be_nil
      end
    end

    context "with an unknown style" do
      subject(:call) { described_class.format_date(iso_date, style: :weird) }

      it "raises ArgumentError" do
        expect { call }.to raise_error(ArgumentError, /Unknown date style/)
      end
    end
  end
end
