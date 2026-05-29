# frozen_string_literal: true

require "omnifocus_mcp/utils/date_filter"

RSpec.describe OmnifocusMcp::Utils::DateFilter do
  let(:today) { Date.new(2026, 3, 26) }

  describe ".parse" do
    describe "number passthrough" do
      it "passes through 0" do
        expect(described_class.parse(0)).to eq(0)
      end

      it "passes through positive integers" do
        expect(described_class.parse(7)).to eq(7)
      end

      it "passes through negative integers" do
        expect(described_class.parse(-1)).to eq(-1)
      end

      it "passes through floats" do
        expect(described_class.parse(3.5)).to eq(3.5)
      end
    end

    describe "named strings" do
      it 'parses "today" to :today' do
        expect(described_class.parse("today")).to eq(:today)
      end

      it 'parses "tomorrow" to :tomorrow' do
        expect(described_class.parse("tomorrow")).to eq(:tomorrow)
      end

      it 'parses "this week" to :this_week' do
        expect(described_class.parse("this week")).to eq(:this_week)
      end

      it 'parses "next week" to :next_week' do
        expect(described_class.parse("next week")).to eq(:next_week)
      end

      it "strips surrounding whitespace before matching" do
        expect(described_class.parse("  today  ")).to eq(:today)
      end

      it "matches Today case-insensitively" do
        expect(described_class.parse("Today")).to eq(:today)
      end

      it "matches THIS WEEK case-insensitively" do
        expect(described_class.parse("THIS WEEK")).to eq(:this_week)
      end

      it "matches Tomorrow case-insensitively" do
        expect(described_class.parse("Tomorrow")).to eq(:tomorrow)
      end
    end

    describe "ISO date strings" do
      it "resolves today's ISO date to 0" do
        expect(described_class.parse("2026-03-26", today: today)).to eq(0)
      end

      it "resolves tomorrow's ISO date to 1" do
        expect(described_class.parse("2026-03-27", today: today)).to eq(1)
      end

      it "resolves a date a week away to 7" do
        expect(described_class.parse("2026-04-02", today: today)).to eq(7)
      end

      it "resolves a past ISO date to a negative number" do
        expect(described_class.parse("2026-03-25", today: today)).to eq(-1)
      end
    end

    describe "today: injection" do
      it "uses the supplied reference date instead of Date.today" do
        expect(described_class.parse("2099-01-01", today: Date.new(2099, 1, 1))).to eq(0)
      end
    end

    describe "error handling" do
      it "raises ArgumentError on unrecognized strings" do
        expect { described_class.parse("next month") }.to raise_error(ArgumentError, /Invalid date filter value/)
      end

      it "raises ArgumentError on the empty string" do
        expect { described_class.parse("") }.to raise_error(ArgumentError, /Invalid date filter value/)
      end

      it "raises ArgumentError on whitespace-only strings" do
        expect { described_class.parse("   ") }.to raise_error(ArgumentError, /Invalid date filter value/)
      end

      it "raises ArgumentError on garbage that doesn't look like a date" do
        expect { described_class.parse("not-a-date") }.to raise_error(ArgumentError, /Invalid date filter value/)
      end

      it "raises ArgumentError on a regex-matching but impossible date" do
        expect { described_class.parse("2026-13-99") }.to raise_error(ArgumentError, /Invalid date filter value/)
      end

      it "raises ArgumentError on a regex-matching but invalid-for-month date" do
        expect { described_class.parse("2026-02-31") }.to raise_error(ArgumentError, /Invalid date filter value/)
      end

      it "raises ArgumentError on a non-string, non-numeric input" do
        expect { described_class.parse(nil) }.to raise_error(ArgumentError, /Invalid date filter value/)
      end

      it "raises ArgumentError on boolean input" do
        expect { described_class.parse(true) }.to raise_error(ArgumentError, /Invalid date filter value/)
      end

      it "includes the format hint in every error" do
        expect { described_class.parse("bogus") }
          .to raise_error(ArgumentError, /ISO date \(YYYY-MM-DD\)/)
      end
    end
  end

  describe ".to_days" do
    it "maps :today to 0" do
      expect(described_class.to_days(:today)).to eq(0)
    end

    it "maps :tomorrow to 1" do
      expect(described_class.to_days(:tomorrow)).to eq(1)
    end

    it "maps :this_week to 7" do
      expect(described_class.to_days(:this_week)).to eq(7)
    end

    it "maps :next_week to 14" do
      expect(described_class.to_days(:next_week)).to eq(14)
    end

    it "passes numeric filters through unchanged" do
      expect(described_class.to_days(3)).to eq(3)
    end
  end

  describe ".resolve" do
    it 'resolves "today" to 0' do
      expect(described_class.resolve("today")).to eq(0)
    end

    it 'resolves "tomorrow" to 1' do
      expect(described_class.resolve("tomorrow")).to eq(1)
    end

    it 'resolves "this week" to 7' do
      expect(described_class.resolve("this week")).to eq(7)
    end

    it 'resolves "next week" to 14' do
      expect(described_class.resolve("next week")).to eq(14)
    end

    it "passes numeric filters through unchanged" do
      expect(described_class.resolve(7)).to eq(7)
    end
  end
end
