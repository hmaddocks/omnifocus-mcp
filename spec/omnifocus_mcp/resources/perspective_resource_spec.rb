# frozen_string_literal: true

require "omnifocus_mcp/resources/perspective_resource"

RSpec.describe OmnifocusMcp::Resources::PerspectiveResource do
  let(:items) { [{ "id" => "p1", "name" => "Daily review", "projectName" => "Routines" }] }
  let(:snake_items) { [{ id: "p1", name: "Daily review", project_name: "Routines" }] }

  context "metadata" do
    it "exposes a templated URI" do
      expect(described_class.uri).to eq("omnifocus://perspective/{name}")
    end

    it "marks the resource as templated" do
      expect(described_class.templated?).to be true
    end

    it "exposes the template variables" do
      expect(described_class.template_variables).to eq(%w[name])
    end

    it "exposes the canonical resource name" do
      expect(described_class.resource_name).to eq("perspective")
    end

    it "describes itself with the expected metadata" do
      expect(described_class.description).to eq("Items visible in a named OmniFocus perspective")
    end
  end

  describe "#payload" do
    subject(:payload) { resource.payload }

    let(:resource) { described_class.initialize_from_uri(uri) }

    before { allow(OmnifocusMcp).to receive(:logger).and_return(instance_double(Logger, warn: nil)) }

    context "when the perspective resolves" do
      let(:uri) { "omnifocus://perspective/Forecast" }
      let(:query_result) { OmnifocusMcp::Result.ok(items) }

      it "calls GetPerspectiveView with the URI name" do
        expect(OmnifocusMcp::Tools::Operations::GetPerspectiveView).to receive(:call).with(
          an_object_having_attributes(perspective_name: "Forecast")
        ).and_return(query_result)

        payload
      end

      it "returns perspective items" do
        allow(OmnifocusMcp::Tools::Operations::GetPerspectiveView).to receive(:call)
          .and_return(query_result)

        expect(payload).to eq(snake_items)
      end
    end

    context "when the perspective name is URL-encoded" do
      let(:uri) { "omnifocus://perspective/Daily%20Review" }
      let(:query_result) { OmnifocusMcp::Result.ok([]) }

      it "passes the decoded name to GetPerspectiveView" do
        expect(OmnifocusMcp::Tools::Operations::GetPerspectiveView).to receive(:call).with(
          an_object_having_attributes(perspective_name: "Daily Review")
        ).and_return(query_result)

        payload
      end

      it "returns an empty array" do
        allow(OmnifocusMcp::Tools::Operations::GetPerspectiveView).to receive(:call)
          .and_return(query_result)

        expect(payload).to eq([])
      end
    end

    context "when GetPerspectiveView returns nil items" do
      let(:successful_with_nil_items) do
        instance_double(OmnifocusMcp::Result).tap do |result|
          allow(result).to receive(:fold) do |on_ok:, **|
            on_ok.call(nil)
          end
        end
      end
      let(:uri) { "omnifocus://perspective/Forecast" }

      before do
        allow(OmnifocusMcp::Tools::Operations::GetPerspectiveView).to receive(:call)
          .and_return(successful_with_nil_items)
      end

      it "returns an empty array" do
        expect(payload).to eq([])
      end
    end

    context "when the URI omits a perspective name" do
      let(:uri) { "omnifocus://perspective/" }
      let(:query_result) { OmnifocusMcp::Result.error("Perspective name is required") }

      it "calls GetPerspectiveView with an empty name" do
        expect(OmnifocusMcp::Tools::Operations::GetPerspectiveView).to receive(:call).with(
          an_object_having_attributes(perspective_name: "")
        ).and_return(query_result)

        payload
      end

      it "surfaces the operation error" do
        allow(OmnifocusMcp::Tools::Operations::GetPerspectiveView).to receive(:call)
          .and_return(query_result)

        expect(payload).to eq({ error: "Perspective name is required" })
      end
    end

    context "when GetPerspectiveView fails" do
      let(:uri) { "omnifocus://perspective/Bogus" }

      before do
        allow(OmnifocusMcp::Tools::Operations::GetPerspectiveView).to receive(:call)
          .and_return(OmnifocusMcp::Result.error("no such perspective"))
      end

      it "returns an error envelope hash" do
        expect(payload).to eq({ error: "no such perspective" })
      end
    end
  end

  describe "#content" do
    subject(:content) { resource.content }

    let(:resource) { described_class.initialize_from_uri(uri) }

    before { allow(OmnifocusMcp).to receive(:logger).and_return(instance_double(Logger, warn: nil)) }

    context "when the perspective resolves" do
      let(:uri) { "omnifocus://perspective/Forecast" }

      it "pretty-prints the payload as JSON" do
        allow(OmnifocusMcp::Tools::Operations::GetPerspectiveView).to receive(:call)
          .and_return(OmnifocusMcp::Result.ok(items))

        expect(content).to eq(JSON.pretty_generate(items))
      end
    end

    context "when GetPerspectiveView returns nil items" do
      let(:successful_with_nil_items) do
        instance_double(OmnifocusMcp::Result).tap do |result|
          allow(result).to receive(:fold) do |on_ok:, **|
            on_ok.call(nil)
          end
        end
      end
      let(:uri) { "omnifocus://perspective/Forecast" }

      before do
        allow(OmnifocusMcp::Tools::Operations::GetPerspectiveView).to receive(:call)
          .and_return(successful_with_nil_items)
      end

      it "pretty-prints an empty array as JSON" do
        expect(content).to eq(JSON.pretty_generate([]))
      end
    end

    context "when GetPerspectiveView fails" do
      let(:uri) { "omnifocus://perspective/Bogus" }

      it "pretty-prints the error envelope as JSON" do
        allow(OmnifocusMcp::Tools::Operations::GetPerspectiveView).to receive(:call)
          .and_return(OmnifocusMcp::Result.error("no such perspective"))

        expect(content).to eq(JSON.pretty_generate(error: "no such perspective"))
      end
    end
  end
end
