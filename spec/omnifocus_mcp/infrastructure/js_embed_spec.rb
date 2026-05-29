# frozen_string_literal: true

require "omnifocus_mcp/infrastructure/js_embed"

RSpec.describe OmnifocusMcp::Infrastructure::JsEmbed do
  describe ".double_quoted_string" do
    context "with plain content" do
      it "returns the string unchanged" do
        expect(described_class.double_quoted_string("hello world")).to eq("hello world")
      end
    end

    context "with double quotes" do
      it "escapes the quotes" do
        expect(described_class.double_quoted_string('test"inject')).to eq('test\\"inject')
      end
    end

    context "with backslashes before quotes" do
      it "escapes backslashes and quotes in one pass" do
        expect(described_class.double_quoted_string('path\\to\\"file')).to eq('path\\\\to\\\\\\"file')
      end
    end

    context "with line breaks" do
      it "escapes newlines and carriage returns" do
        expect(described_class.double_quoted_string("line1\nline2\rline3")).to eq('line1\\nline2\\rline3')
      end
    end
  end

  describe ".template_literal" do
    context "with backslashes" do
      it "escapes them" do
        expect(described_class.template_literal('a\b')).to eq('a\\\\b')
      end
    end

    context "with backticks" do
      it "escapes them" do
        expect(described_class.template_literal("a`b")).to eq('a\\`b')
      end
    end

    context "with dollar signs" do
      it "escapes them" do
        expect(described_class.template_literal("a$b")).to eq('a\\$b')
      end
    end

    context "with all escapable template characters" do
      it "escapes them in a single pass" do
        expect(described_class.template_literal('a\b`c$d')).to eq('a\\\\b\\`c\\$d')
      end
    end
  end
end
