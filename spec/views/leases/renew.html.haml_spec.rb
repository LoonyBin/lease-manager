# frozen_string_literal: true

require "rails_helper"

RSpec.describe "leases/renew" do
  subject { Capybara.string(rendered) }

  before do
    lease = create(:lease)
    assign(:lease, Lease.new(lease.attributes.except("id", "created_at", "updated_at")))
    assign(:renewing_from, lease)
    render
  end

  it { is_expected.to have_css("h2", text: "Renew Lease") }
  it { is_expected.to have_css("form[method='post']") }
  it { is_expected.to have_select("lease[property_id]") }
  it { is_expected.to have_select("lease[tenant_id]") }
  it { is_expected.to have_field("lease[start_date]") }
  it { is_expected.to have_field("lease[duration_months]") }
  it { is_expected.to have_button("Renew") }
end
