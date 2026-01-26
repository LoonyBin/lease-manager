require 'rails_helper'

RSpec.describe "tenants/show", type: :view do
  before(:each) do
    @tenant = assign(:tenant, create(:tenant, name: "Name", email: "Email", phone_number: "Phone"))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
    expect(rendered).to match(/Email/)
    expect(rendered).to match(/Phone/)
  end
end
