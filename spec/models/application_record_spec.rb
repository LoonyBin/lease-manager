# frozen_string_literal: true

require "rails_helper"

# Guards the Ransack allowlists locked down in #173. The old blanket default
# (ApplicationRecord exposing every column + every association) let /users filter
# on api_tokens.token_digest and use the match/no-match response as an oracle to
# recover the digest one prefix at a time.
#
# These assertions are deliberately scoped to ApplicationRecord descendants.
# Version (< PaperTrail::Version) knowingly still returns column_names; its wider
# object/object_changes exposure is tracked separately in #178 and is out of
# scope here — so the "never returns column_names" claim below is not global.
RSpec.describe ApplicationRecord do
  # Column names that look like a credential and must never be searchable.
  let(:sensitive_column) { /digest|secret|password|token|_key\b|\bkey\b/i }

  # Concrete, table-backed descendants only — skip abstract bases and any
  # table-less descendant (e.g. an STI root without its own table).
  let(:searchable_models) do
    Rails.application.eager_load!
    described_class.descendants.reject { |m| m.abstract_class? || !m.table_exists? }
  end

  let(:secret_leaks) do
    searchable_models.filter_map do |model|
      leaked = model.ransackable_attributes & model.column_names.grep(sensitive_column)
      "#{model.name} → #{leaked.join(', ')}" if leaked.any?
    end
  end

  # A superset check, not exact equality: a model returning `column_names` *plus*
  # a ransacker (the exact shape of the old fail-open default,
  # column_names + _ransackers.keys) would slip past an equality test.
  let(:wholesale_models) do
    searchable_models.select { |m| (m.column_names - m.ransackable_attributes).empty? }.map(&:name)
  end

  describe "the Ransack allowlist policy across all descendants" do
    it "fails closed at the base class", :aggregate_failures do
      expect(described_class.ransackable_attributes).to eq([])
      expect(described_class.ransackable_associations).to eq([])
    end

    # Quiet today: the only secret-shaped column on an ApplicationRecord table is
    # api_tokens.token_digest, and ApiToken's allowlist is []. This fails the day
    # someone makes a password/secret/digest/token/key column ransackable.
    it "never exposes a secret-shaped column to Ransack" do
      expect(secret_leaks).to be_empty, "sensitive columns exposed to Ransack:\n#{secret_leaks.join("\n")}"
    end

    # A model that returns its full column list is almost certainly inheriting a
    # blanket default rather than a deliberate, reviewed allowlist.
    it "never allowlists a model's full column list wholesale" do
      expect(wholesale_models).to be_empty
    end

    it "does not expose the api_tokens.token_digest oracle (AC#1)", :aggregate_failures do
      expect(ApiToken.ransackable_attributes).not_to include("token_digest")
      expect(User.ransackable_associations).not_to include("api_tokens")
    end
  end

  # Invoice#number, Property#capacity and User#created_at are sortable from the
  # _sort drawers (or a controller default) but appear in no _search partial, so
  # they have no form-render safety net. Ransack silently drops a non-allowlisted
  # sort, so dropping one of these from an allowlist would quietly stop the sort
  # working. These assert the sort still reorders (fails closed if the entry goes
  # away — the attribute would be ignored and the ids come back in insertion order).
  describe "sort-only allowlist entries stay sortable" do
    it "keeps Invoice#number sortable" do
      low = create(:invoice, number: "1")
      high = create(:invoice, number: "2")
      ordered = Invoice.where(id: [low.id, high.id]).ransack(s: "number desc").result.pluck(:id)
      expect(ordered).to eq([high.id, low.id])
    end

    it "keeps Property#capacity sortable" do
      low = create(:property, capacity: 1)
      high = create(:property, capacity: 99)
      ordered = Property.where(id: [low.id, high.id]).ransack(s: "capacity desc").result.pluck(:id)
      expect(ordered).to eq([high.id, low.id])
    end

    it "keeps User#created_at sortable" do
      older = create(:user, created_at: 2.days.ago)
      newer = create(:user, created_at: 1.day.ago)
      ordered = User.where(id: [older.id, newer.id]).ransack(s: "created_at desc").result.pluck(:id)
      expect(ordered).to eq([newer.id, older.id])
    end
  end
end
