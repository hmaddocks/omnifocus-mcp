# frozen_string_literal: true

require "omnifocus_mcp/infrastructure/apple_script_date_builder"
require "omnifocus_mcp/utils/date_formatting"

RSpec.describe OmnifocusMcp::Infrastructure::AppleScriptDateBuilder do
  describe ".create_date_outside_tell_block" do
    subject(:script) { described_class.create_date_outside_tell_block(iso_date_string, "testDate") }

    context "with a date-only string" do
      let(:iso_date_string) { "2026-04-10" }

      it "sets the calendar day" do
        expect(script).to include("set day of testDate to 10")
      end

      it "sets the calendar month" do
        expect(script).to include("set month of testDate to 4")
      end

      it "sets the calendar year" do
        expect(script).to include("set year of testDate to 2026")
      end

      it "defaults hours to midnight local time" do
        expect(script).to include("set hours of testDate to 0")
      end
    end

    context "with a datetime string" do
      let(:iso_date_string) { "2026-04-10T17:30:45" }

      it "preserves the specified hours" do
        expect(script).to include("set hours of testDate to 17")
      end

      it "preserves the specified minutes" do
        expect(script).to include("set minutes of testDate to 30")
      end

      it "preserves the specified seconds" do
        expect(script).to include("set seconds of testDate to 45")
      end
    end

    context "with an invalid date string" do
      let(:iso_date_string) { "not-a-date" }

      it "raises ArgumentError" do
        expect { script }.to raise_error(ArgumentError, /Invalid date string/)
      end
    end
  end

  describe ".generate_date_assignment" do
    context "when iso_date_string is nil" do
      it "returns nil" do
        expect(described_class.generate_date_assignment("theTask", "due date", nil)).to be_nil
      end
    end

    context "when iso_date_string is empty" do
      subject(:parts) { described_class.generate_date_assignment("theTask", "due date", "") }

      it "returns an empty pre_script" do
        expect(parts.pre_script).to eq("")
      end

      it "clears the date property" do
        expect(parts.assignment_script).to eq("set due date of theTask to missing value")
      end
    end

    context "when iso_date_string is a date" do
      subject(:parts) { described_class.generate_date_assignment("theTask", "due date", "2026-04-10") }

      let(:var_name) { parts.assignment_script.match(/to (dateVar\w+)\z/)[1] }

      it "references the generated variable in the assignment" do
        expect(parts.assignment_script).to match(/to dateVar\w+\z/)
      end

      it "copies current date to the generated variable in pre_script" do
        expect(parts.pre_script).to include("copy current date to #{var_name}")
      end

      it "assigns the property on the target object" do
        expect(parts.assignment_script).to eq("set due date of theTask to #{var_name}")
      end
    end

    context "when called twice with the same inputs" do
      it "generates unique variable names across calls" do
        a = described_class.generate_date_assignment("t", "due date", "2026-04-10")
        b = described_class.generate_date_assignment("t", "due date", "2026-04-10")
        expect(a.assignment_script).not_to eq(b.assignment_script)
      end
    end

    context "when returning DateAssignmentParts" do
      subject(:parts) { described_class.generate_date_assignment("t", "due date", "") }

      it "is a DateAssignmentParts value" do
        expect(parts).to be_a(described_class::DateAssignmentParts)
      end
    end
  end
end

RSpec.describe OmnifocusMcp::Utils::DateFormatting do
  it "is a deprecated alias for Infrastructure::AppleScriptDateBuilder" do
    expect(described_class).to equal(OmnifocusMcp::Infrastructure::AppleScriptDateBuilder)
  end
end
