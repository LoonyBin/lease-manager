# frozen_string_literal: true

require "rails_helper"

RSpec.describe GenerateInvoicesJob do
  describe "#perform" do
    let(:batch_generator) { instance_double(BatchInvoiceGenerator) }

    before do
      allow(BatchInvoiceGenerator).to receive(:new).and_return(batch_generator)
      allow(batch_generator).to receive(:call)
    end

    it "calls BatchInvoiceGenerator", :aggregate_failures do
      described_class.new.perform
      expect(BatchInvoiceGenerator).to have_received(:new)
      expect(batch_generator).to have_received(:call)
    end
  end
end
