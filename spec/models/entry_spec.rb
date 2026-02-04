# frozen_string_literal: true

require "rails_helper"

RSpec.describe Entry do
  describe "associations" do
    it { is_expected.to belong_to(:lease) }
    it { is_expected.to belong_to(:instrument) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:amount) }

    it "validates amount is not zero", :aggregate_failures do
      lease = create(:lease)
      invoice = create(:invoice, lease: lease, status: :draft)

      entry = described_class.new(lease: lease, instrument: invoice, amount: 0, transaction_id: nil)
      expect(entry).not_to be_valid
      expect(entry.errors[:amount]).to include("must be other than 0")
    end
  end

  describe "scopes" do
    let(:lease) { create(:lease) }
    let(:invoice) { create(:invoice, lease: lease, status: :draft) }
    let(:payment) { create(:payment, lease: lease) }

    before do
      # Clear auto-created entries from payment
      described_class.delete_all
    end

    describe ".initial" do
      it "returns entries without a transaction_id" do
        initial = described_class.create!(lease: lease, instrument: invoice, amount: 100, transaction_id: nil)
        described_class.create!(lease: lease, instrument: invoice, amount: -50, transaction_id: SecureRandom.uuid)

        expect(described_class.initial).to contain_exactly(initial)
      end
    end

    describe ".settlements" do
      it "returns entries with a transaction_id" do
        described_class.create!(lease: lease, instrument: invoice, amount: 100, transaction_id: nil)
        txn_id = SecureRandom.uuid
        settlement = described_class.create!(lease: lease, instrument: invoice, amount: -50, transaction_id: txn_id)

        expect(described_class.settlements).to contain_exactly(settlement)
      end
    end

    describe ".for_transaction" do
      it "returns entries for a specific transaction" do
        txn_id = SecureRandom.uuid
        entry1 = described_class.create!(lease: lease, instrument: invoice, amount: -50, transaction_id: txn_id)
        entry2 = described_class.create!(lease: lease, instrument: payment, amount: 50, transaction_id: txn_id)
        described_class.create!(lease: lease, instrument: invoice, amount: 100, transaction_id: nil)

        expect(described_class.for_transaction(txn_id)).to contain_exactly(entry1, entry2)
      end
    end
  end
end
