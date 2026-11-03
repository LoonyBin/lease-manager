# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScheduleInvoiceRemindersJob do
  describe "#perform" do
    let(:scheduler) { instance_double(Reminders::BatchScheduler) }

    before do
      allow(Reminders::BatchScheduler).to receive(:new).and_return(scheduler)
      allow(scheduler).to receive(:call)
    end

    it "calls Reminders::BatchScheduler", :aggregate_failures do
      described_class.new.perform
      expect(Reminders::BatchScheduler).to have_received(:new)
      expect(scheduler).to have_received(:call)
    end
  end
end
