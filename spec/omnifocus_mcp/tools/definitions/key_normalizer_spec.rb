# frozen_string_literal: true

require "omnifocus_mcp/tools/definitions/key_normalizer"

RSpec.describe OmnifocusMcp::Tools::Definitions::KeyNormalizer do
  describe ".snake_case_key" do
    it "leaves snake_case symbols untouched" do
      expect(described_class.snake_case_key(:due_date)).to eq(:due_date)
    end

    it "downcases simple camelCase symbols" do
      expect(described_class.snake_case_key(:dueDate)).to eq(:due_date)
    end

    it "handles multi-word camelCase symbols" do
      expect(described_class.snake_case_key(:parentTaskId)).to eq(:parent_task_id)
    end

    it "converts String keys to snake_case Symbols" do
      expect(described_class.snake_case_key("parentTaskId")).to eq(:parent_task_id)
    end

    it "passes non-Symbol/String keys through unchanged" do
      expect(described_class.snake_case_key(42)).to eq(42)
    end
  end

  describe ".snake_keys" do
    context "with a shallow Hash" do
      subject(:result) { described_class.snake_keys({ dueDate: "2026-05-23", parentTaskId: "T1" }) }

      it "rewrites every key to snake_case" do
        expect(result).to eq(due_date: "2026-05-23", parent_task_id: "T1")
      end
    end

    context "with deep: false (default)" do
      subject(:result) { described_class.snake_keys({ filters: { dueDate: "2026-05-23" } }) }

      it "leaves nested Hashes and Arrays untouched" do
        expect(result).to eq(filters: { dueDate: "2026-05-23" })
      end
    end

    context "with deep: true" do
      it "recurses into nested Hashes" do
        expect(described_class.snake_keys({ filters: { dueDate: "2026-05-23" } }, deep: true))
          .to eq(filters: { due_date: "2026-05-23" })
      end

      it "recurses into Arrays of Hashes" do
        expect(described_class.snake_keys(
                 { items: [{ dueDate: "1", parentTaskId: "p" }, { dueDate: "2" }] },
                 deep: true
               ))
          .to eq(items: [{ due_date: "1", parent_task_id: "p" }, { due_date: "2" }])
      end

      it "recurses into a top-level Array of Hashes" do
        expect(described_class.snake_keys([{ dueDate: "1" }], deep: true))
          .to eq([{ due_date: "1" }])
      end
    end

    context "with String-keyed input" do
      subject(:result) { described_class.snake_keys({ "dueDate" => "2026-05-23", "parentTaskId" => "T1" }) }

      it "rewrites every String key to a snake_case Symbol" do
        expect(result).to eq(due_date: "2026-05-23", parent_task_id: "T1")
      end
    end

    context "with a non-Hash value" do
      subject(:result) { described_class.snake_keys("not a hash") }

      it "passes scalars through unchanged" do
        expect(result).to eq("not a hash")
      end
    end
  end

  describe ".camel_case_key" do
    it "converts snake_case Symbols to camelCase Strings" do
      expect(described_class.camel_case_key(:parent_task_id)).to eq("parentTaskId")
    end

    it "converts snake_case Strings to camelCase Strings" do
      expect(described_class.camel_case_key("due_date")).to eq("dueDate")
    end

    it "leaves single-word keys as Strings" do
      expect(described_class.camel_case_key(:name)).to eq("name")
    end

    it "passes non-Symbol/String keys through unchanged" do
      expect(described_class.camel_case_key(42)).to eq(42)
    end
  end

  describe ".camel_keys" do
    context "with a nested Hash" do
      subject(:result) { described_class.camel_keys({ due_date: "1", filters: { parent_task_id: "p" } }) }

      it "rewrites keys at every level" do
        expect(result).to eq("dueDate" => "1", "filters" => { "parentTaskId" => "p" })
      end
    end

    context "with a top-level Array of Hashes" do
      subject(:result) { described_class.camel_keys([{ due_date: "1" }, { due_date: "2" }]) }

      it "rewrites keys in every element" do
        expect(result).to eq([{ "dueDate" => "1" }, { "dueDate" => "2" }])
      end
    end

    context "with a non-Hash value" do
      subject(:result) { described_class.camel_keys("not a hash") }

      it "passes scalars through unchanged" do
        expect(result).to eq("not a hash")
      end
    end
  end
end
