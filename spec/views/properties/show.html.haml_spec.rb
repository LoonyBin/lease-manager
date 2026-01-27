# frozen_string_literal: true

require "rails_helper"

RSpec.describe "properties/show" do
  subject { rendered }

  before do
    @property = assign(:property, create(:property, name: "Name", address: "MyText"))
    render
  end

  it { is_expected.to match(/Name/) }
  it { is_expected.to match(/MyText/) }
end
