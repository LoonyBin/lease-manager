# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserAssociation do
  subject { build(:user_association) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:associable) }
  end

  describe "validations" do
    it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(%i[associable_type associable_id]) }
  end

  describe "polymorphic association" do
    it "can associate with an owner" do
      owner = create(:owner)
      association = create(:user_association, associable: owner)
      expect(association.associable).to eq(owner)
    end

    it "can associate with a tenant" do
      tenant = create(:tenant)
      association = create(:user_association, associable: tenant)
      expect(association.associable).to eq(tenant)
    end
  end
end
