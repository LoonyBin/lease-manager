# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tenant do
  subject { build(:tenant) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:phone_number) }
  end
end
