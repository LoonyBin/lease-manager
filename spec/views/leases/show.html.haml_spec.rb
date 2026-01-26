# frozen_string_literal: true

require "rails_helper"

RSpec.describe "leases/show" do
  before do
    @lease = assign(:lease, create(:lease))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/#{@lease.property.name}/)
    expect(rendered).to match(/#{@lease.tenant.name}/)
    expect(rendered).to match(/12 months/)
    expect(rendered).to match(/1,000.00/)
  end
end
