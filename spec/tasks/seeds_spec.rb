# frozen_string_literal: true

require "rails_helper"

# db/seeds.rb rotted unnoticed: #159 removed InvoiceGenerator and the seed file
# kept calling it, so `db:seed` raised NameError on every fresh database for
# months. Nothing in CI ran it. These examples run the real file against the
# real database so that cannot happen again — Dokku's predeploy is db:prepare,
# which seeds on database creation, so a broken seed file breaks a rebuild.
RSpec.describe "db/seeds.rb", type: :task do # -- Seed file spec
  # One owner with six properties, one of them left unleased: enough to reach
  # all five lease scenarios and the renewal, small enough to run quickly.
  def seed_env
    { "SEED_OWNERS" => "1", "SEED_PROPERTIES_PER_OWNER" => "6",
      "SEED_TENANTS" => "2", "SEED_UNLEASED_PROPERTIES" => "1" }
  end

  around do |example|
    original = ENV.to_hash
    ENV.update(seed_env)
    example.run
  ensure
    ENV.replace(original)
  end

  # The seed file reports its progress on stdout; swallow it.
  def run_seed
    original = $stdout
    $stdout = StringIO.new
    Rails.application.load_seed
  ensure
    $stdout = original
  end

  it "seeds a dataset the application can actually use", :aggregate_failures do
    expect { run_seed }.not_to raise_error

    expect(Invoice.where.not(invoice_template_id: nil)).to be_any
    expect(Invoice.finalized_or_later.where(number: nil)).to be_empty
    expect(Payment.count).to be_positive
    expect(User.pluck(:email)).to include("admin@example.com", "user@example.com")
  end

  # Seed against a database that already holds a row. "Created nothing" is not
  # enough on its own: the file's first act after the guard is destroy_all
  # across eight tables, so a guard placed one line too late would wipe a live
  # database and still leave an empty one unchanged.
  it "refuses to seed a production database, and destroys nothing", :aggregate_failures do
    existing = create(:user)
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

    expect { run_seed }.not_to change(User, :count)
    expect(User.exists?(existing.id)).to be(true)
  end
end
