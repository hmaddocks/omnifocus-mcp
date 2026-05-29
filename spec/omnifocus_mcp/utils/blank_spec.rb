# frozen_string_literal: true

require "omnifocus_mcp/utils/blank"

# Lightweight blank predicate: nil or empty to_s; variadic form is AND-of-blanks.
RSpec.describe OmnifocusMcp::Utils::Blank do
  describe ".blank?" do
    context "with a single value" do
      subject(:blank) { described_class.blank?(value) }

      context "when value is nil" do
        let(:value) { nil }

        it "is true" do
          expect(blank).to be true
        end
      end

      context "when value is an empty string" do
        let(:value) { "" }

        it "is true" do
          expect(blank).to be true
        end
      end

      context "when value is a whitespace-only string" do
        let(:value) { "   " }

        it "is false (unlike ActiveSupport, whitespace is not stripped)" do
          expect(blank).to be false
        end
      end

      context "when value is a non-empty string" do
        let(:value) { "hello" }

        it "is false" do
          expect(blank).to be false
        end
      end

      context "when value is a number" do
        let(:value) { 0 }

        it "is false (to_s is non-empty)" do
          expect(blank).to be false
        end
      end

      context "when value is false" do
        let(:value) { false }

        it "is false (`false.to_s` is \"false\", not empty)" do
          expect(blank).to be false
        end
      end

      context "when value is true" do
        let(:value) { true }

        it "is false (`true.to_s` is \"true\", not empty)" do
          expect(blank).to be false
        end
      end

      context "when value is an object with an empty to_s" do
        let(:value) { Object.new.tap { |o| o.define_singleton_method(:to_s) { "" } } }

        it "is true" do
          expect(blank).to be true
        end
      end
    end

    context "with multiple values (variadic AND-of-blanks)" do
      subject(:blank) { described_class.blank?(*values) }

      context "when every argument is blank" do
        let(:values) { [nil, ""] }

        it "is true" do
          expect(blank).to be true
        end
      end

      context "when three arguments are all blank" do
        let(:values) { [nil, "", nil] }

        it "is true" do
          expect(blank).to be true
        end
      end

      context "when any argument is present" do
        let(:values) { [nil, "x"] }

        it "is false" do
          expect(blank).to be false
        end
      end

      context "when a middle argument is present among three" do
        let(:values) { [nil, "", "x"] }

        it "is false" do
          expect(blank).to be false
        end
      end

      context "with no arguments" do
        let(:values) { [] }

        it "is true vacuously" do
          expect(blank).to be true
        end
      end
    end
  end
end
