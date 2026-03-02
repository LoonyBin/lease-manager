# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tenant do
  subject { build(:tenant) }

  describe "associations" do
    it { is_expected.to have_many(:user_associations).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:user_associations) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
  end
end
