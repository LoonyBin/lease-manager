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
  end
end
