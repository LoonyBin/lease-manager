# frozen_string_literal: true

require "rails_helper"

# Unpadded decimal string, e.g. "1180.0" or "0.13".
DECIMAL_STRING = /\A-?\d+(\.\d+)?\z/
# "%b %Y" month label, e.g. "Jan 2026".
MONTH_LABEL = /\A[A-Z][a-z]{2} \d{4}\z/
REPORT_KEYS = %w[total_revenue total_outstanding total_taxes total_collected
                 revenue_by_month payments_by_month occupancy_stats invoice_status_distribution].freeze

RSpec.describe "Reports" do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  # Bearer header for an API token belonging to +token_user+.
  def bearer(token_user)
    token = create(:api_token, user: token_user)
    { "Authorization" => "Bearer #{token.plaintext_token}" }
  end

  describe "GET /reports" do
    context "when unauthenticated" do
      it "redirects to login" do
        get reports_path
        expect(response).to redirect_to(login_path)
      end
    end

    context "when authenticated as normal user" do
      before do
        sign_in_as(user)
        get reports_path
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(response.body).to include("Overview") }
    end

    context "when authenticated as admin" do
      before do
        sign_in_admin
      end

      it "returns http success" do
        get reports_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  # The other three actions had no request-level coverage, so nothing guarded
  # their HTML path against the respond_to change. These pin it.
  describe "HTML actions beyond index" do
    before { sign_in_admin }

    it "renders the revenue page", :aggregate_failures do
      get revenue_reports_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Revenue by Month")
    end

    it "renders the outstanding page", :aggregate_failures do
      get outstanding_reports_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Outstanding Invoices")
    end

    it "renders the taxes page", :aggregate_failures do
      get taxes_reports_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Taxes by Month")
    end
  end

  describe "JSON via API token" do
    describe "smoke tests" do
      it_behaves_like "serves JSON with a valid API token" do
        let(:json_path) { reports_path(format: :json) }
      end

      it_behaves_like "serves JSON with a valid API token" do
        let(:json_path) { revenue_reports_path(format: :json) }
      end

      it_behaves_like "serves JSON with a valid API token" do
        let(:json_path) { outstanding_reports_path(format: :json) }
      end

      it_behaves_like "serves JSON with a valid API token" do
        let(:json_path) { taxes_reports_path(format: :json) }
      end
    end

    describe "payload shapes" do
      before do
        lease = create(:lease, property: create(:property, name: "Sea View"))
        invoice = create(:invoice, :with_balance, balance_amount: 500, lease: lease, status: :finalized)
        create(:line_item, invoice: invoice, amount: 1000, tax_rate: 18)
      end

      it "exposes the aggregate keys as decimal strings and enum status keys", :aggregate_failures do
        get reports_path(format: :json), headers: bearer(admin)
        body = response.parsed_body
        expect(body.keys).to include(*REPORT_KEYS)
        expect(body["total_revenue"]).to match(DECIMAL_STRING)
        expect(body["invoice_status_distribution"]).to include("finalized")
      end

      it "groups revenue by month and by property (array, not name-keyed)", :aggregate_failures do
        get revenue_reports_path(format: :json), headers: bearer(admin)
        body = response.parsed_body
        expect(body["by_month"].values).to all(match(DECIMAL_STRING))
        expect(body["by_property"]).to all(include("property_id", "property", "amount"))
        expect(body["by_property"].first["property"]).to eq("Sea View")
      end

      it "returns a trimmed invoice shape for outstanding, not the full attribute bag", :aggregate_failures do
        get outstanding_reports_path(format: :json), headers: bearer(admin)
        entry = response.parsed_body["invoices"].first
        expect(entry.keys).to contain_exactly("id", "number", "date", "due_date",
                                              "outstanding_amount", "lease", "property", "tenant")
        expect(entry).not_to include("balance", "status")
      end

      it "serializes the outstanding total as a decimal string" do
        get outstanding_reports_path(format: :json), headers: bearer(admin)
        expect(response.parsed_body["total_outstanding"]).to match(DECIMAL_STRING)
      end

      it "labels tax months and serializes the total as a string", :aggregate_failures do
        get taxes_reports_path(format: :json), headers: bearer(admin)
        body = response.parsed_body
        expect(body["total_taxes"]).to match(DECIMAL_STRING)
        expect(body["by_month"].keys).to all(match(MONTH_LABEL))
      end
    end

    describe "collected revenue" do
      let(:lease) { create(:lease) }
      # The bucket label today's fixtures land in, e.g. "Aug 2026".
      let(:this_month) { Time.zone.today.strftime("%b %Y") }

      def index_body
        get reports_path(format: :json), headers: bearer(admin)
        response.parsed_body
      end

      it "excludes draft and rejected payments from total_collected", :aggregate_failures do
        create(:payment, lease: lease, amount: 1000, status: :confirmed, date: Time.zone.today)
        create(:payment, lease: lease, amount: 500, status: :draft, date: Time.zone.today)
        create(:payment, lease: lease, amount: 250, status: :rejected, date: Time.zone.today)

        # Positive control: only the confirmed 1000 survives; draft/rejected drop out.
        expect(index_body["total_collected"]).to eq("1000.0")
      end

      it "nets a confirmed refund against payments in total_collected" do
        create(:payment, lease: lease, amount: 1000, status: :confirmed, date: Time.zone.today)
        create(:payment, :refund, lease: lease, amount: 300, status: :confirmed, date: Time.zone.today)

        # 1000 collected minus a 300 refund (a debit) = 700, pinning the sign.
        expect(index_body["total_collected"]).to eq("700.0")
      end

      it "counts only the confirmed amount in the payments_by_month bucket" do
        create(:payment, lease: lease, amount: 1000, status: :confirmed, date: Time.zone.today)
        create(:payment, lease: lease, amount: 500, status: :draft, date: Time.zone.today)
        create(:payment, lease: lease, amount: 250, status: :rejected, date: Time.zone.today)

        # Exact bucket total, not an absence check: draft/rejected in the same
        # month must not lift it above the confirmed 1000.
        expect(index_body["payments_by_month"][this_month]).to eq("1000.0")
      end
    end

    describe "tax total rounding" do
      # Each line's tax is 1.00 * 12.5 / 100 = 0.125, which rounds half-up to
      # 0.13, so two lines total 0.26. Summing unrounded would give 0.25 and
      # disagree with the index endpoint and the by_month rows, which round per
      # line. (A single line would not catch this: money() already rounds 0.125
      # up to "0.13", so it takes two lines to expose an unrounded sum.)
      before do
        invoice = create(:invoice, status: :finalized)
        create_list(:line_item, 2, invoice: invoice, amount: 1.00, tax_rate: 12.5)
      end

      it "rounds each line half-up before summing" do
        get taxes_reports_path(format: :json), headers: bearer(admin)
        expect(response.parsed_body["total_taxes"]).to eq("0.26")
      end

      it "reports the same total_taxes on the index and taxes endpoints" do
        get reports_path(format: :json), headers: bearer(admin)
        index_total = response.parsed_body["total_taxes"]
        get taxes_reports_path(format: :json), headers: bearer(admin)
        expect(response.parsed_body["total_taxes"]).to eq(index_total).and eq("0.26")
      end
    end

    describe "scoping" do
      it "serves a scoped 200 for a non-admin token" do
        get reports_path(format: :json), headers: bearer(user)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
