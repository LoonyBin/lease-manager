# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApiToken do
  describe "token generation" do
    it "exposes the plaintext with the identifying prefix" do
      token = create(:api_token)
      expect(token.plaintext_token).to start_with(described_class::TOKEN_PREFIX)
    end

    it "persists only the SHA-256 digest of the plaintext" do
      token = create(:api_token)
      expect(token.token_digest).to eq(described_class.digest(token.plaintext_token))
    end

    it "does not expose the plaintext after reload" do
      token = create(:api_token)
      expect(described_class.find(token.id).plaintext_token).to be_nil
    end

    it "requires a name" do
      expect(build(:api_token, name: "")).not_to be_valid
    end
  end

  describe "permissions" do
    it "defaults to the full grantable set (mirrors the old read_write default)" do
      expect(build(:api_token).permissions).to eq(ApiToken::PermissionRegistry.full_preset)
    end

    it "answers permits? by set membership", :aggregate_failures do
      token = build(:api_token, :custom, permissions: %w[invoices#index payments#create])
      expect(token.permits?("invoices#index")).to be(true)
      expect(token.permits?("payments#create")).to be(true)
      expect(token.permits?("leases#destroy")).to be(false)
    end

    it "normalizes entries to a sorted, de-duplicated list" do
      token = create(:api_token, :custom, permissions: %w[payments#create invoices#index invoices#index])
      expect(token.permissions).to eq(%w[invoices#index payments#create])
    end

    it "rejects non-string entries with a validation error", :aggregate_failures do
      token = build(:api_token, :custom, permissions: [123, :symbol])
      expect(token).not_to be_valid
      expect(token.errors[:permissions]).to be_present
    end

    it "accepts non-registry entries so the token-management invariant stays testable" do
      # No subset validation: a token can be created carrying api_tokens#create.
      # The guard, not the model, is what refuses it — see
      # spec/requests/api_token_management_invariant_spec.rb.
      expect(build(:api_token, :custom, permissions: %w[api_tokens#create])).to be_valid
    end

    it "is immutable after creation (attr_readonly)", :aggregate_failures do
      token = create(:api_token, :read_only)
      expect { token.update!(permissions: ApiToken::PermissionRegistry.full_preset) }
        .to raise_error(ActiveRecord::ReadonlyAttributeError)
      expect(token.reload.permissions).to eq(ApiToken::PermissionRegistry.read_preset)
    end
  end

  describe "#orphaned_grants" do
    it "returns granted actions absent from the registry" do
      token = build(:api_token, :custom, permissions: %w[invoices#index gone#missing])
      expect(token.orphaned_grants).to eq(%w[gone#missing])
    end

    it "is empty for a preset token" do
      expect(build(:api_token, :read_only).orphaned_grants).to be_empty
    end
  end

  describe "preset" do
    it "accepts the known labels and nil (custom)", :aggregate_failures do
      expect(build(:api_token, :custom, preset: nil)).to be_valid
      expect(build(:api_token, preset: "full")).to be_valid
      expect(build(:api_token, :read_only, preset: "read_only")).to be_valid
    end

    it "rejects an unknown label such as \"custom\"", :aggregate_failures do
      token = build(:api_token, :custom, preset: "custom")
      expect(token).not_to be_valid
      expect(token.errors[:preset]).to be_present
    end

    it "is immutable after creation (attr_readonly)" do
      token = create(:api_token, preset: "full")
      expect { token.update!(preset: "read_only") }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end
  end

  describe ".authenticate" do
    it "returns the token matching a valid plaintext" do
      token = create(:api_token)
      expect(described_class.authenticate(token.plaintext_token)).to eq(token)
    end

    it "returns nil for an unknown plaintext" do
      expect(described_class.authenticate("lmt_unknown")).to be_nil
    end

    it "returns nil for a blank plaintext" do
      expect(described_class.authenticate("")).to be_nil
    end

    it "returns nil for a revoked token" do
      token = create(:api_token)
      token.revoke!
      expect(described_class.authenticate(token.plaintext_token)).to be_nil
    end

    it "returns nil for an expired token" do
      token = create(:api_token, expires_at: 1.day.ago)
      expect(described_class.authenticate(token.plaintext_token)).to be_nil
    end

    it "returns a token whose expiry is in the future" do
      token = create(:api_token, expires_at: 1.day.from_now)
      expect(described_class.authenticate(token.plaintext_token)).to eq(token)
    end
  end

  describe ".active" do
    it "excludes revoked and expired tokens" do
      active = create(:api_token)
      create(:api_token, :revoked)
      create(:api_token, :expired)
      expect(described_class.active).to contain_exactly(active)
    end
  end

  describe "#revoke!" do
    it "sets revoked_at" do
      token = create(:api_token)
      expect { token.revoke! }.to change(token, :revoked?).from(false).to(true)
    end
  end

  describe "#expired?" do
    it "is false without an expiry" do
      expect(build(:api_token).expired?).to be(false)
    end

    it "is true past the expiry" do
      expect(build(:api_token, :expired).expired?).to be(true)
    end
  end

  describe "#touch_last_used" do
    it "records the time of use" do
      token = create(:api_token)
      expect { token.touch_last_used }.to change(token, :last_used_at).from(nil)
    end

    it "skips the write when touched again within the throttle window" do
      token = create(:api_token)
      token.touch_last_used
      expect { token.touch_last_used }.not_to change(token, :last_used_at)
    end

    it "writes again once the throttle window has passed" do
      token = create(:api_token)
      token.touch_last_used
      travel(described_class::LAST_USED_THROTTLE + 1.second) do
        expect { token.touch_last_used }.to change(token, :last_used_at)
      end
    end

    it "does not create an audit version" do
      token = create(:api_token)
      expect { token.touch_last_used }.not_to change(PaperTrail::Version, :count)
    end
  end

  describe "audit trail" do
    it "records a version on create" do
      token = create(:api_token)
      expect(token.versions.where(event: "create")).to exist
    end

    it "records a version on revoke" do
      token = create(:api_token)
      expect { token.revoke! }.to change(token.versions, :count).by(1)
    end

    it "never serializes the token digest into versions" do
      token = create(:api_token)
      token.revoke!
      serialized = token.versions.reload.map { |v| [v.object, v.object_changes].join }.join
      expect(serialized).not_to include(token.token_digest)
    end

    it "captures the granted permissions in the create version, still without the digest", :aggregate_failures do
      # The exact granted array, not merely a "permissions" substring — the old
      # `include("scope")` assertion passed for any token regardless of value.
      # PaperTrail stores a jsonb column double-encoded (a JSON string inside the
      # JSON object_changes), so the "to" value is parsed once more to compare.
      token = create(:api_token, :custom, permissions: %w[invoices#index payments#create])
      create_version = token.versions.find_by(event: "create")
      granted = JSON.parse(JSON.parse(create_version.object_changes)["permissions"].last)
      expect(granted).to eq(%w[invoices#index payments#create])
      expect([create_version.object, create_version.object_changes].join).not_to include(token.token_digest)
    end
  end
end
