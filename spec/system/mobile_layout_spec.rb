# frozen_string_literal: true

require "rails_helper"

# Phone-width layout checks: the page body must never scroll sideways (only data
# tables may), navigation must be reachable, and forms must be usable.
# PDF viewing is not tested: the app has no invoice PDF feature, only print CSS.
RSpec.describe "Mobile layout" do
  let(:admin) { create(:user, :admin) }
  let(:lease) { create(:lease) }

  around do |example|
    wait = Capybara.default_max_wait_time
    Capybara.default_max_wait_time = 8
    example.run
  ensure
    Capybara.default_max_wait_time = wait
  end

  before { sign_in_through_browser(admin) }

  def each_phone
    [[375, 667], [390, 844], [768, 1024]].each do |w, h|
      resize_to(w, h)
      yield w
    end
  end

  def expect_no_page_overflow(label = nil)
    overflow = page_overflow
    width = page.evaluate_script("window.innerWidth")
    expect(overflow).to be <= 0, "#{label} overflows the page by #{overflow}px at #{width}"
  end

  def expect_columns_aligned(list)
    header, *rows = column_lefts("#{list} .resource-list-header, #{list} .resource-item, #{list} .version-list-header")
    expect(rows).not_to be_empty
    expect(rows).to all(eq(header))
  end

  # Two statement lines: an invoice with a long amount and a payment.
  def seed_statement
    invoice = create(:invoice, lease: lease)
    lease.entries.create!(instrument: invoice, amount: 12_345_678)
    create(:payment, lease: lease, date: Date.current, amount: 500) # confirmed, so it books its own entry
  end

  def seed_properties(count)
    owner = create(:owner)
    now = Time.current
    rows = (1..count).map do |i|
      { owner_id: owner.id, name: "Property #{i}", address: "Addr #{i}", created_at: now, updated_at: now }
    end
    Property.insert_all(rows) # rubocop:disable Rails/SkipsModelValidations
  end

  # Controls stay in DOM order, inside the content column, on exactly `rows` rows.
  def expect_pagination_inside_column(rows)
    boxes = pagination_boxes
    expect(boxes.pluck("top").uniq.size).to eq(rows)
    expect_in_reading_order(boxes)
    expect_inside_column(boxes)
  end

  def expect_in_reading_order(boxes)
    expect(boxes.size).to be >= 15
    expect(boxes).to eq(boxes.sort_by { |b| b.values_at("top", "left") })
  end

  def expect_inside_column(boxes)
    column = box_of(".app-main")
    expect(boxes.pluck("left").min).to be >= column["left"] - 0.5
    expect(boxes.pluck("right").max).to be <= column["right"] + 0.5
  end

  describe "pages without sideways scrolling" do
    it "login page" do
      page.driver.browser.cookies.clear
      each_phone do
        visit "/login"
        expect_no_page_overflow("login")
      end
    end

    it "lease page with long reminder recipients" do
      create(:reminder_step, lease: lease,
                             to_emails: ["a.very.long.recipient.name.for.testing@subdomain.example-company.com",
                                         "another.extremely.long.mailbox.name@subdomain.example-company.com"])
      create(:payment, lease: lease)
      each_phone do |w|
        visit lease_path(lease)
        expect_no_page_overflow("lease")
        expect_inside_viewport(".show-list-item .btn", vertical: false) if w < 1024
      end
    end

    it "lease statement, scrolling to its Balance column with columns aligned" do
      seed_statement
      each_phone do |w|
        visit lease_path(lease)
        expect_no_page_overflow("lease statement")
        expect(page).to have_css(".lease-statement-list .resource-item", count: 2)
        expect_columns_aligned(".lease-statement-list")
        next if w >= 1024

        page.execute_script("document.querySelector('.lease-statement-list').scrollLeft = 99999")
        expect_inside_viewport(".lease-statement-list .resource-list-header > :last-child", vertical: false)
        expect_inside_viewport(".lease-statement-list .resource-item > :last-child", vertical: false)
        expect(first(".lease-statement-list .resource-item > :last-child")).to have_text("₹12,345,678")
      end
    end

    it "invoice page" do
      invoice = create(:invoice, lease: lease)
      invoice.line_items.create!(name: "Rent for November 2025", category: "rent", amount: 1000, tax_rate: 18)
      each_phone do
        visit invoice_path(invoice)
        expect_no_page_overflow("invoice")
      end
    end

    it "draft payment page for an admin" do
      payment = create(:payment, status: :draft, lease: lease)
      each_phone do
        visit payment_path(payment)
        expect_no_page_overflow("payment")
        expect(box_of(".page-title")["width"]).to be > 0
        expect_inside_viewport(".page-actions", vertical: false)
      end
    end

    it "new invoice and new invoice template forms, including the line-item tables" do
      each_phone do
        visit new_invoice_path(invoice: { lease_id: lease.id })
        expect_no_page_overflow("invoice form")
        visit new_lease_invoice_template_path(lease)
        expect_no_page_overflow("invoice template form")
      end
    end

    it "lease, reminder step and other forms with long hints" do
      each_phone do
        visit new_lease_path
        expect_no_page_overflow("lease form")
        visit new_lease_reminder_step_path(lease)
        expect_no_page_overflow("reminder step form")
      end
    end

    it "audit trail, scrolling to its last column" do
      create(:payment, lease: lease)
      PaperTrail.request(whodunnit: admin.id) { lease.update!(rent_amount: 1234) }
      each_phone do |w|
        visit versions_path
        expect_no_page_overflow("audit trail")
        next if w >= 1024

        page.execute_script("document.querySelector('.version-list').scrollLeft = 99999")
        expect_inside_viewport(".version-list .version-item .version-col-actions", vertical: false)
      end
    end

    it "filtered index with several active filters" do
      each_phone do
        visit leases_path(q: { tenant_name_cont: "a", property_name_cont: "b", status_eq: "x", rent_amount_gteq: "1" })
        expect_no_page_overflow("filtered leases")
      end
    end

    it "long paginated list wraps into ordered rows inside the content column" do
      seed_properties(600)
      { 375 => 3, 390 => 3, 768 => 2 }.each do |w, rows|
        resize_to(w, 800)
        visit properties_path(page: 10)
        expect_no_page_overflow("properties page 10 at #{w}")
        expect_pagination_inside_column(rows)
      end
    end

    it "short paginated list stays inside the viewport" do
      seed_properties(60)
      [375, 390, 768].each do |w|
        resize_to(w, 800)
        visit properties_path(page: 2)
        expect_no_page_overflow("properties page 2 at #{w}")
        expect_inside_viewport(".join > *:first-child", vertical: false)
        expect_inside_viewport(".join > *:last-child", vertical: false)
      end
    end
  end

  describe "the lease '+' menu" do
    before { create(:lease) } # a second lease, so the intended lease id is not the only one available

    it "stays on screen, at the top and after scrolling, and opens forms for this lease" do
      resize_to(375, 667)
      create_list(:payment, 10, lease: lease)
      visit lease_path(lease)
      expect(page.evaluate_script("document.documentElement.scrollHeight")).to be > 667
      expect(computed_style(".app-header", "position")).to eq("sticky")

      find("[title='Create']").click
      expect_inside_viewport(".page-actions .dropdown-content")
      header_bottom = box_of(".app-header")["bottom"]
      expect(box_of(".page-actions .dropdown-content")["top"]).to be >= header_bottom - 1

      page.execute_script("window.scrollTo(0, 800)")
      expect(page.evaluate_script("window.scrollY")).to be > 0
      unless page.has_css?(".page-actions .dropdown-content", visible: :visible, wait: 0.5)
        find("[title='Create']").click
      end
      expect_inside_viewport(".page-actions .dropdown-content")
      expect(box_of(".page-actions .dropdown-content")["top"]).to be >= box_of(".app-header")["bottom"] - 1

      click_link "New Invoice"
      expect(page).to have_current_path(%r{/invoices/new})
      expect(find("form.new_invoice input[name='invoice[lease_id]']", visible: :all).value).to eq(lease.id.to_s)

      visit lease_path(lease)
      find("[title='Create']").click
      click_link "Record Payment"
      expect(page).to have_current_path(%r{/payments/new})
      expect(find_field("payment[lease_id]", type: :hidden, visible: :all).value).to eq(lease.id.to_s)
    end

    it "stays on screen on a property page and opens a lease form for that property" do
      property = create(:property)
      create(:property)
      resize_to(320, 640)
      visit property_path(property)
      first("[title='Create']").click
      expect_inside_viewport(".page-actions .dropdown-content")
      click_link "New Lease"
      expect(page).to have_current_path(%r{/leases/new})
      field = find("[name='lease[property_id]']", visible: :all)
      expect(field.value).to eq(property.id.to_s)
    end
  end

  describe "forms can be submitted from a phone" do
    before { resize_to(375, 667) }

    it "creates an invoice with a line item" do
      visit new_invoice_path(invoice: { lease_id: lease.id })
      find("form.new_invoice input[type=date][name='invoice[date]']").set(Date.current.iso8601)
      click_button "Add Line Item"
      within(all("[data-nested-fields-target=container] tr").last) do
        find("input[name$='[name]']").set("Rent")
        find("input[name$='[category]']").set("rent")
        find("input[name$='[amount]']").set("500")
      end
      expect do
        find(".form-actions .btn-primary").click
        expect(page).to have_no_current_path(%r{/invoices/new})
      end.to change { lease.invoices.count }.by(1)
      expect(lease.invoices.last.line_items.pluck(:name)).to eq(["Rent"])
    end

    it "creates an invoice template with two line items" do
      visit new_lease_invoice_template_path(lease)
      fill_in "Name", with: "Mobile template"
      all("[data-controller=duration-input] input").last.set("9")
      click_button "Add Line Item"
      rows = all("[data-nested-fields-target=container] tr")
      rows.each_with_index do |row, i|
        within(row) do
          find("input[name$='[name]']").set("Item #{i}")
          find("input[name$='[category]']").set("rent")
          find("input[name$='[amount_expression]']").set("100")
        end
      end
      page.execute_script("document.querySelector('.overflow-x-auto').scrollLeft = 99999")
      rows.size.times do |i|
        row = "[data-nested-fields-target=container] tr:nth-child(#{i + 1})"
        find("#{row} input[name$='[tax_rate]']").set("18")
        expect_inside_viewport("#{row} input[name$='[tax_rate]']", vertical: false)
        expect_inside_viewport("#{row} td:last-child", vertical: false)
      end
      expect_inside_viewport("[data-action='nested-fields#add']", vertical: false)
      page.execute_script("document.querySelector('[formaction*=preview]').scrollIntoView()")
      expect_inside_viewport("[formaction*=preview]", vertical: false)
      expect_inside_viewport(".form-actions .btn-primary", vertical: false)
      expect do
        find(".form-actions .btn-primary").click
        expect(page).to have_no_current_path(%r{/invoice_templates/new})
      end.to change { lease.invoice_templates.count }.by(1)
      expect(lease.invoice_templates.find_by(name: "Mobile template").line_items.count).to eq(2)
    end

    it "records a payment" do
      visit new_payment_path(payment: { lease_id: lease.id })
      fill_in "Date", with: Date.current
      fill_in "Amount", with: "4321"
      find("select[name='payment[mode]'] option[value='upi']").select_option
      fill_in "Reference number", with: "REF123"
      expect_inside_viewport("select[name='payment[mode]']", vertical: false)
      expect_inside_viewport("input[type=file]", vertical: false)
      expect do
        find(".form-actions .btn-primary").click
        expect(page).to have_no_current_path(%r{/payments/new})
      end.to change { lease.payments.count }.by(1)
      expect(lease.payments.last).to have_attributes(amount: 4321, mode: "upi", reference_number: "REF123")
    end

    it "confirms a draft payment" do
      payment = create(:payment, status: :draft, lease: lease)
      visit payment_path(payment)
      accept_confirm { click_button "Confirm" }
      expect(page).to have_no_button("Confirm")
      expect(payment.reload).not_to be_draft
    end

    it "reaches the submit button on the remaining forms" do
      [new_lease_path, new_property_path, new_owner_path, new_tenant_path, new_user_path,
       new_lease_reminder_step_path(lease)].each do |path|
        visit path
        expect_no_page_overflow(path)
        page.execute_script("document.querySelector('.form-actions .btn-primary').scrollIntoView()")
        expect_inside_viewport(".form-actions .btn-primary", vertical: false)
      end
    end
  end

  describe "navigation" do
    it "opens the drawer from the logo, follows a link and reaches Logout" do
      resize_to(375, 667)
      visit root_path
      first(".app-header label[for]").click
      expect(page).to have_link("Leases", visible: :visible)
      click_link "Leases", match: :first
      expect(page).to have_current_path(leases_path)
      first(".app-header label[for]").click
      find("summary", text: "Settings").click
      expect(page).to have_button("Logout", visible: :visible)
      click_button "Logout"
      expect(page).to have_button("Sign in with Developer")
    end
  end

  describe "desktop regression" do
    [1024, 1280].each do |w|
      it "keeps the header on one row and lists unchanged at #{w}" do
        resize_to(w, 800)
        payment = create(:payment, status: :draft, lease: lease)
        visit payment_path(payment)
        expect(box_of(".app-header")["height"]).to be_within(1).of(64)
        title = box_of(".page-title")
        actions = box_of(".page-actions")
        expect(title["width"]).to be > 0
        expect((title["top"] + title["bottom"]) / 2).to be_within(1).of((actions["top"] + actions["bottom"]) / 2)
        expect_inside_viewport(".page-actions", vertical: false)

        visit versions_path
        expect(computed_style(".version-list", "overflowX")).to eq("hidden")
      end

      it "keeps line-item tables fitting without scrolling at #{w}" do
        resize_to(w, 800)
        visit new_invoice_path(invoice: { lease_id: lease.id })
        expect(horizontal_slack(".overflow-x-auto")).to eq(0)
        visit new_lease_invoice_template_path(lease)
        expect(horizontal_slack(".overflow-x-auto")).to eq(0)
      end

      it "paginates on a single row where it fits at #{w}" do
        seed_properties(60)
        resize_to(w, 800)
        visit properties_path(page: 2)
        expect(pagination_row_count).to eq(1)
        expect_no_page_overflow("desktop pagination")
      end

      it "wraps a long pagination into the agreed rows at #{w}" do
        seed_properties(600)
        resize_to(w, 800)
        visit properties_path(page: 10)
        expect_no_page_overflow("long desktop pagination")
        expect_pagination_inside_column(w == 1024 ? 2 : 1)
      end

      it "keeps the lease statement columns aligned and unscrolled at #{w}" do
        seed_statement
        resize_to(w, 800)
        visit lease_path(lease)
        expect_columns_aligned(".lease-statement-list")
        expect(computed_style(".lease-statement-list", "overflowX")).to eq("hidden")
        expect(horizontal_slack(".lease-statement-list")).to eq(0)
      end
    end
  end
end
