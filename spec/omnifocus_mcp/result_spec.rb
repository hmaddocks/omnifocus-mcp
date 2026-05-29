# frozen_string_literal: true

require "omnifocus_mcp/result"

RSpec.describe OmnifocusMcp::Result do
  describe ".ok" do
    subject(:result) { described_class.ok("payload") }

    it "produces a Result whose value is the wrapped payload" do
      expect(result.value).to eq("payload")
    end

    it "leaves error_message nil" do
      expect(result.error_message).to be_nil
    end

    it "captures the call site in creation_location" do
      expect(result.creation_location.path).to end_with("result_spec.rb")
    end

    it "rejects a nil value" do
      expect { described_class.ok(nil) }.to raise_error(ArgumentError, /Must provide/)
    end

    it "accepts a `false` value (only `nil` is forbidden)" do
      expect(described_class.ok(false).value).to be false
    end

    it "accepts an empty string value" do
      expect(described_class.ok("").value).to eq("")
    end
  end

  describe ".error" do
    subject(:result) { described_class.error("boom") }

    it "produces a Result whose error_message is the wrapped message" do
      expect(result.error_message).to eq("boom")
    end

    it "leaves value nil" do
      expect(result.value).to be_nil
    end

    it "captures the call site in creation_location" do
      expect(result.creation_location.path).to end_with("result_spec.rb")
    end

    it "rejects a nil message" do
      expect { described_class.error(nil) }.to raise_error(ArgumentError, /Must provide/)
    end

    it "accepts an empty string message" do
      expect(described_class.error("").error_message).to eq("")
    end
  end

  describe "#ok?" do
    it "is true for a success result" do
      expect(described_class.ok(1).ok?).to be true
    end

    it "is false for an error result" do
      expect(described_class.error("x").ok?).to be false
    end
  end

  describe "#error?" do
    it "is false for a success result" do
      expect(described_class.ok(1).error?).to be false
    end

    it "is true for an error result" do
      expect(described_class.error("x").error?).to be true
    end
  end

  describe "#ok" do
    it "returns the wrapped value when successful" do
      expect(described_class.ok(42).ok).to eq(42)
    end

    it "raises when called on an error result" do
      expect { described_class.error("boom").ok }.to raise_error(RuntimeError, /Cannot get value/)
    end
  end

  describe "#ok_or" do
    it "returns the wrapped value when successful" do
      expect(described_class.ok(42).ok_or(0)).to eq(42)
    end

    it "returns the default when the result is an error" do
      expect(described_class.error("boom").ok_or(0)).to eq(0)
    end

    it "returns false when the ok value is false (not treated as missing)" do
      expect(described_class.ok(false).ok_or(true)).to be(false)
    end

    it "returns zero when the ok value is zero (not treated as missing)" do
      expect(described_class.ok(0).ok_or(99)).to eq(0)
    end
  end

  describe "invariants" do
    let(:location) { caller_locations(1, 1).first }

    it "rejects construction with both a value and an error message" do
      expect do
        described_class.new(value: 1, error_message: "boom", creation_location: location)
      end.to raise_error(ArgumentError, /Cannot have both/)
    end

    it "rejects construction with both false and an error message" do
      expect do
        described_class.new(value: false, error_message: "boom", creation_location: location)
      end.to raise_error(ArgumentError, /Cannot have both/)
    end
  end

  describe "#error" do
    it "returns the wrapped message when erroneous" do
      expect(described_class.error("boom").error).to eq("boom")
    end

    it "raises when called on a successful result" do
      expect { described_class.ok(1).error }.to raise_error(RuntimeError, /Cannot get error/)
    end
  end

  describe "#map" do
    it "applies the block to the value and rewraps in ok" do
      expect(described_class.ok(2).map { |x| x * 10 }.ok).to eq(20)
    end

    it "is a no-op on an error result" do
      r = described_class.error("boom")
      expect(r.map { |x| x * 10 }).to be(r)
    end

    it "marks the result as an error when the block raises" do
      r = described_class.ok(1).map { raise "kaboom" } # rubocop: disable Lint/UnreachableLoop
      expect(r.error?).to be true
    end

    it "captures the exception message as the error payload" do
      r = described_class.ok(1).map { raise "kaboom" } # rubocop: disable Lint/UnreachableLoop
      expect(r.error).to eq("kaboom")
    end
  end

  describe "#and_then" do
    it "chains success → success via the block's Result" do
      r = described_class.ok(1).and_then { |x| described_class.ok(x + 1) }
      expect(r.ok).to eq(2)
    end

    it "short-circuits when the block returns an error Result" do
      r = described_class.ok(1).and_then { |_| described_class.error("nope") }
      expect(r.error?).to be true
    end

    it "preserves the error message when the block returns an error Result" do
      r = described_class.ok(1).and_then { |_| described_class.error("nope") }
      expect(r.error).to eq("nope")
    end

    it "is a no-op on an error result" do
      r = described_class.error("boom")
      expect(r.and_then { |_| described_class.ok(99) }).to be(r)
    end
  end

  describe "#or_else" do
    it "is a no-op on a success" do
      r = described_class.ok(1)
      expect(r.or_else { |_| described_class.ok(99) }).to be(r)
    end

    it "runs the block on an error result" do
      r = described_class.error("boom").or_else { |msg| described_class.ok(msg.length) }
      expect(r.ok).to eq(4)
    end
  end

  describe "#fold" do
    let(:on_ok) { ->(value) { "ok:#{value}" } }
    let(:on_error) { ->(message) { "err:#{message}" } }

    it "calls on_ok with the wrapped value when successful" do
      expect(described_class.ok(42).fold(on_ok: on_ok, on_error: on_error)).to eq("ok:42")
    end

    it "calls on_error with the wrapped message when erroneous" do
      expect(described_class.error("boom").fold(on_ok: on_ok, on_error: on_error)).to eq("err:boom")
    end

    it "returns the lambda's return value verbatim (does NOT re-wrap in a Result)" do
      hash_result = described_class.ok(:thing).fold(
        on_ok: ->(value) { { kind: value } },
        on_error: ->(_) { :unused }
      )
      expect(hash_result).to eq({ kind: :thing })
    end
  end

  describe "#where" do
    it "aliases creation_location" do
      result = described_class.ok(1)
      expect(result.where).to eq(result.creation_location)
    end
  end

  describe ".zip" do
    it "pairs two ok values into a 2-tuple ok" do
      r = described_class.zip(described_class.ok(1), described_class.ok(2))
      expect(r.ok).to eq([1, 2])
    end

    it "returns the left error when left is an error" do
      r = described_class.zip(described_class.error("L"), described_class.ok(2))
      expect(r.error).to eq("L")
    end

    it "returns the right error when right is an error (and left is ok)" do
      r = described_class.zip(described_class.ok(1), described_class.error("R"))
      expect(r.error).to eq("R")
    end

    it "returns the left error when both sides are errors" do
      r = described_class.zip(described_class.error("L"), described_class.error("R"))
      expect(r.error).to eq("L")
    end
  end

  describe ".all" do
    context "with an Array" do
      it "returns Result.ok([]) for an empty array" do
        r = described_class.all([])
        expect(r.ok).to eq([])
      end

      it "returns Result.ok with the unwrapped values when every Result is ok" do
        r = described_class.all([described_class.ok(1), described_class.ok(2), described_class.ok(3)])
        expect(r.ok).to eq([1, 2, 3])
      end

      it "preserves false ok values" do
        r = described_class.all([described_class.ok(false), described_class.ok(0)])
        expect(r.ok).to eq([false, 0])
      end

      it "returns the first error in iteration order" do
        r = described_class.all([
                                  described_class.ok(1),
                                  described_class.error("first"),
                                  described_class.error("second")
                                ])
        expect(r.error).to eq("first")
      end
    end

    context "with a Hash" do
      it "returns Result.ok({}) for an empty hash" do
        r = described_class.all({})
        expect(r.ok).to eq({})
      end

      it "returns Result.ok with a hash of unwrapped values when every Result is ok" do
        r = described_class.all(a: described_class.ok(1), b: described_class.ok(2))
        expect(r.ok).to eq(a: 1, b: 2)
      end

      it "returns the first error in insertion order" do
        r = described_class.all(
          a: described_class.ok(1),
          b: described_class.error("first"),
          c: described_class.error("second")
        )
        expect(r.error).to eq("first")
      end
    end

    it "raises ArgumentError for unsupported containers" do
      expect { described_class.all("not a container") }.to raise_error(ArgumentError, /Array or Hash/)
    end
  end

  describe "pattern matching" do
    it "supports array deconstruction for an ok result" do
      case described_class.ok(42)
      in [Integer => n, nil] then expect(n).to eq(42)
      else                        raise "expected ok pattern"
      end
    end

    it "supports array deconstruction for an error result" do
      case described_class.error("boom")
      in [nil, String => msg] then expect(msg).to eq("boom")
      else                         raise "expected error pattern"
      end
    end

    it "supports hash deconstruction with explicit keys" do
      case described_class.ok(:thing)
      in { value: } then expect(value).to eq(:thing)
      else               raise "expected value match"
      end
    end

    it "supports hash deconstruction for an error result" do
      case described_class.error("boom")
      in { error_message: msg } then expect(msg).to eq("boom")
      else                           raise "expected error_message match"
      end
    end
  end
end
