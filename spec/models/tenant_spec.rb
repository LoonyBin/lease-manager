# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tenant do
  describe "validations" do
    it "is valid with valid attributes" do
      tenant = build(:tenant)
      expect(tenant).to be_valid
    end

    it "is invalid without a name" do
      tenant = build(:tenant, name: nil)
      expect(tenant).not_to be_valid
      expect(tenant.errors[:name]).to include("can't be blank")
    end

    it "is invalid without an email" do
      tenant = build(:tenant, email: nil)
      expect(tenant).not_to be_valid
      expect(tenant.errors[:email]).to include("can't be blank")
    end

    it "is invalid without a phone number" do
      tenant = build(:tenant, phone_number: nil)
      expect(tenant).not_to be_valid
      expect(tenant.errors[:phone_number]).to include("can't be blank")
    end
  end
end
