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

ActiveRecord::Schema[8.0].define(version: 2026_01_26_102933) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "leases", force: :cascade do |t|
    t.bigint "property_id", null: false
    t.bigint "tenant_id", null: false
    t.date "start_date"
    t.integer "duration_months"
    t.date "terminated_on"
    t.decimal "rent_amount"
    t.integer "security_deposit_in_months"
    t.integer "enhancement_period_months"
    t.decimal "enhancement_percentage"
    t.decimal "enhancement_fixed_amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_leases_on_property_id"
    t.index ["tenant_id"], name: "index_leases_on_tenant_id"
  end

  create_table "properties", force: :cascade do |t|
    t.string "name"
    t.text "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tenants", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "phone_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "leases", "properties"
  add_foreign_key "leases", "tenants"
end
