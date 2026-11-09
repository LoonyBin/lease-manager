# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Financial search" do
  # Both listings must preserve result sets, order and the form's submitted keys.
  # Draft fixtures avoid notification delivery and settlement side effects.
  shared_examples "a financial search" do |resource, amount_field|
    let(:lease) { create(:lease, security_deposit_value: 0) }
    let!(:records) { [100, 200, 300].map { |amount| financial_record(resource, lease, amount) } }

    def low
      records[0]
    end

    def middle
      records[1]
    end

    def high
      records[2]
    end

    let(:path) { public_send("#{resource}_path") }

    def financial_record(resource, lease, amount)
      return create(:payment, lease: lease, amount: amount, status: :draft) if resource == :payments

      create(:invoice, lease: lease, status: :draft).tap do |invoice|
        create(:line_item, invoice: invoice, amount: amount, tax_rate: 0)
      end
    end

    def response_ids
      response.parsed_body.pluck("id")
    end

    def rendered_ids(html, resource)
      html.css(".resource-list .resource-item.#{resource.to_s.singularize}-item").map do |row|
        Integer(row["data-clickable-row-url-value"].delete_prefix("#{path}/"), 10)
      end
    end

    context "with an admin session" do
      before { sign_in_admin }

      def submit_sort_control(amount_field, direction)
        get path
        control = response.parsed_body.at_css("input[name='q[s]'][value='#{amount_field} #{direction}']")
        expect(control).to be_present
        form = control.ancestors("form").first
        query = Rack::Utils.parse_nested_query(URI.encode_www_form(control["name"] => control["value"]))
        get form["action"], params: query, as: :json
      end

      def expect_all_rendered_records(resource)
        expect(rendered_ids(response.parsed_body, resource)).to contain_exactly(low.id, middle.id, high.id)
      end

      def search_form(resource)
        get path
        expect_all_rendered_records(resource)
        form = response.parsed_body.at_css("form##{resource.to_s.singularize}_search")
        expect(form).to be_present
        expect(form["method"].downcase).to eq("get")
        form
      end

      def filter_query(form, amount_field)
        minimum = form.at_css("input[name='q[#{amount_field}_gteq]']")
        maximum = form.at_css("input[name='q[#{amount_field}_lteq]']")
        Rack::Utils.parse_nested_query(URI.encode_www_form(minimum["name"] => "150", maximum["name"] => "250"))
      end

      def expect_field_value(name, value)
        expect(response.parsed_body.at_css("input[name='#{name}']")["value"].to_d).to eq(value)
      end

      def expect_filtered_html(resource, amount_field)
        expect(response).to have_http_status(:ok)
        expect_field_value("q[#{amount_field}_gteq]", 150)
        expect_field_value("q[#{amount_field}_lteq]", 250)
        expect(rendered_ids(response.parsed_body, resource)).to eq([middle.id])
      end

      def submit_filter_form(resource, amount_field)
        form = search_form(resource)
        query = filter_query(form, amount_field)
        get form["action"], params: query
        expect_filtered_html(resource, amount_field)
        get form["action"], params: query, as: :json
      end

      %w[asc desc].each do |direction|
        it "submits the page's amount sort control #{direction}", :aggregate_failures do
          submit_sort_control(amount_field, direction)
          expected = [low.id, middle.id, high.id]
          expect(response).to have_http_status(:ok)
          expect(response_ids).to eq(direction == "asc" ? expected : expected.reverse)
        end
      end

      it "submits the rendered search fields and preserves their values", :aggregate_failures do
        submit_filter_form(resource, amount_field)
        expect(response_ids).to eq([middle.id])
      end
    end

    context "with an ordinary tenant session" do
      let(:user) { create(:user) }

      before do
        create(:user_association, user: user, associable: lease.tenant)
        sign_in_as(user)
      end

      it "does not expose another tenant's matching records", :aggregate_failures do
        financial_record(resource, create(:lease, security_deposit_value: 0), 200)
        get path, params: { q: { "#{amount_field}_gteq" => "200" } }, as: :json
        expect(response).to have_http_status(:ok)
        expect(response_ids).to contain_exactly(middle.id, high.id)
      end
    end

    context "with an API token" do
      let(:user) { create(:user) }

      let(:token) { create(:api_token, :custom, user: user, permissions: ["#{resource}#index"]) }

      before { create(:user_association, user: user, associable: lease.tenant) }

      it "applies the user's scope when the index action is granted", :aggregate_failures do
        financial_record(resource, create(:lease, security_deposit_value: 0), 200)
        get path, params: { q: { "#{amount_field}_gteq" => "200" } },
                  headers: { "Authorization" => "Bearer #{token.plaintext_token}" }, as: :json
        expect(response).to have_http_status(:ok)
        expect(response_ids).to contain_exactly(middle.id, high.id)
      end
    end
  end

  describe "invoices" do
    it_behaves_like "a financial search", :invoices, :total_amount
  end

  describe "payments" do
    it_behaves_like "a financial search", :payments, :amount
  end
end
