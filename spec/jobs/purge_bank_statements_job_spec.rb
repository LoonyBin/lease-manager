# frozen_string_literal: true

require "rails_helper"

RSpec.describe PurgeBankStatementsJob do
  describe "#perform" do
    let(:purger) { instance_double(BankStatementPurger) }

    before do
      allow(BankStatementPurger).to receive(:new).and_return(purger)
      allow(purger).to receive(:call)
    end

    it "calls BankStatementPurger", :aggregate_failures do
      described_class.new.perform
      expect(BankStatementPurger).to have_received(:new)
      expect(purger).to have_received(:call)
    end
  end

  describe "recurring schedule" do
    let(:config) { Rails.application.config_for(:recurring, env: "production") }
    let(:task) { SolidQueue::RecurringTask.from_configuration("purge_bank_statements", **config.fetch(:purge_bank_statements)) }

    it "runs this job daily", :aggregate_failures do
      expect(task).to be_valid
      expect(task.command).to eq("#{described_class}.perform_later")
      expect(task.schedule).to eq("0 2 * * *")
    end
  end
end
