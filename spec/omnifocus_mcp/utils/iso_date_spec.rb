# frozen_string_literal: true

require "omnifocus_mcp/utils/iso_date"

RSpec.describe OmnifocusMcp::Utils::IsoDate do
  describe ".to_date_only" do
    it "returns YYYY-MM-DD for ISO date strings" do
      expect(described_class.to_date_only("2026-05-23")).to eq("2026-05-23")
    end

    it "extracts the date from ISO timestamps" do
      expect(described_class.to_date_only("2026-05-23T15:00:00Z")).to eq("2026-05-23")
    end

    it "returns nil for nil" do
      expect(described_class.to_date_only(nil)).to be_nil
    end

    it "returns nil for empty input" do
      expect(described_class.to_date_only("")).to be_nil
    end

    it "returns nil for unparseable input" do
      expect(described_class.to_date_only("not-a-real-date")).to be_nil
    end
  end
end
