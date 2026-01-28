# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_01_28_040403) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "invoices", force: :cascade do |t|
    t.bigint "lease_id", null: false
    t.date "date"
    t.integer "status", default: 0
    t.string "number"
    t.integer "sequence_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lease_id"], name: "index_invoices_on_lease_id"
  end

  create_table "leases", force: :cascade do |t|
    t.bigint "property_id", null: false
    t.bigint "tenant_id", null: false
    t.date "start_date"
    t.integer "duration_months"
    t.date "terminated_on"
    t.decimal "rent_amount"
    t.integer "security_deposit_in_months"
    t.integer "enhancement_period_months"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "enhancement_amount", precision: 10, scale: 2
    t.integer "enhancement_type", default: 0
    t.string "tax_name"
    t.decimal "tax_rate", precision: 5, scale: 2
    t.index ["property_id"], name: "index_leases_on_property_id"
    t.index ["tenant_id"], name: "index_leases_on_tenant_id"
  end

  create_table "line_items", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.string "name"
    t.decimal "amount", precision: 10, scale: 2
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "tax_rate", precision: 5, scale: 3, default: "0.0"
    t.index ["invoice_id"], name: "index_line_items_on_invoice_id"
  end

  create_table "owners", force: :cascade do |t|
    t.string "name"
    t.text "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "invoice_sequence", default: 0
  end

  create_table "payment_allocations", force: :cascade do |t|
    t.bigint "payment_id", null: false
    t.bigint "invoice_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_payment_allocations_on_invoice_id"
    t.index ["payment_id"], name: "index_payment_allocations_on_payment_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "lease_id", null: false
    t.date "date", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "mode"
    t.string "reference_number"
    t.index ["lease_id"], name: "index_payments_on_lease_id"
  end

  create_table "properties", force: :cascade do |t|
    t.string "name"
    t.text "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "owner_id", null: false
    t.index ["owner_id"], name: "index_properties_on_owner_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "phone_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "invoices", "leases"
  add_foreign_key "leases", "properties"
  add_foreign_key "leases", "tenants"
  add_foreign_key "line_items", "invoices"
  add_foreign_key "payment_allocations", "invoices"
  add_foreign_key "payment_allocations", "payments"
  add_foreign_key "payments", "leases"
  add_foreign_key "properties", "owners"
end
