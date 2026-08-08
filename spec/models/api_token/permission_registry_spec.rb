# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiToken::PermissionRegistry do
  describe ".grantable_actions" do
    subject(:grantable) { described_class.grantable_actions }

    it "is a sorted, de-duplicated list" do
      expect(grantable).to eq(grantable.uniq.sort)
    end

    it "excludes new/edit (best-effort JSON filter)" do
      expect(grantable.grep(/#(new|edit)\z/)).to be_empty
    end

    # A security exclusion, distinct from the new/edit filter above.
    it "excludes api_tokens#* (belt-and-braces behind the hard invariant)", :aggregate_failures do
      expect(grantable).not_to include("api_tokens#create")
      expect(grantable).not_to include("api_tokens#destroy")
    end

    it "excludes sessions#* (needs the browser session / OmniAuth)", :aggregate_failures do
      expect(grantable).not_to include("sessions#create")
      expect(grantable).not_to include("sessions#destroy")
      expect(grantable).not_to include("sessions#new")
    end

    it "includes resourceful and non-CRUD member actions", :aggregate_failures do
      expect(grantable).to include("invoices#index", "payments#create", "properties#destroy")
      expect(grantable).to include("invoice_notifications#approve")
    end
  end

  describe ".read_preset" do
    it "is the GET/HEAD-reachable subset of the grantable set", :aggregate_failures do
      expect(described_class.read_preset - described_class.grantable_actions).to be_empty
      expect(described_class.read_preset).to include("invoices#index", "invoices#show", "reports#revenue")
      expect(described_class.read_preset).not_to include("properties#create", "properties#destroy")
    end
  end

  describe ".full_preset" do
    it "is exactly the grantable set (enumerated, not a wildcard)" do
      expect(described_class.full_preset).to eq(described_class.grantable_actions)
    end
  end

  describe ".grouped" do
    it "groups actions under their controller" do
      expect(described_class.grouped["invoices"]).to include("index", "show", "create", "update")
    end

    it "never surfaces a security-excluded controller", :aggregate_failures do
      expect(described_class.grouped).not_to have_key("api_tokens")
      expect(described_class.grouped).not_to have_key("sessions")
    end
  end
end
