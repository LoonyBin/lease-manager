# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankStatement do
  subject(:bank_statement) { build(:bank_statement) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:filename) }
    it { is_expected.to validate_presence_of(:uploaded_at) }
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, processed: 1) }
  end

  describe "audit trail" do
    it "keeps the filename out of versions", :aggregate_failures do
      statement = create(:bank_statement, filename: "acct-123456789-march.csv")
      statement.update!(filename: "acct-987654321-april.csv", status: statement.pending? ? :processed : :pending)
      serialized = statement.versions.reload.map { |v| [v.object, v.object_changes].join }.join
      expect(statement.versions.count).to be >= 2
      expect(serialized).not_to match(/123456789|987654321/)
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:bank_transactions).dependent(:destroy) }

    it "does not store the uploaded file" do
      expect(described_class.reflect_on_attachment(:file)).to be_nil
    end
  end
end
