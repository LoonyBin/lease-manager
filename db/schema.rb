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

ActiveRecord::Schema[8.1].define(version: 2026_02_10_081557) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "entries", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.bigint "instrument_id", null: false
    t.string "instrument_type", null: false
    t.bigint "lease_id", null: false
    t.uuid "transaction_id"
    t.datetime "updated_at", null: false
    t.index ["instrument_type", "instrument_id"], name: "index_entries_on_instrument"
    t.index ["lease_id"], name: "index_entries_on_lease_id"
    t.index ["transaction_id"], name: "index_entries_on_transaction_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.decimal "balance", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.date "date"
    t.integer "document_type", default: 0, null: false
    t.bigint "lease_id", null: false
    t.string "number"
    t.integer "sequence_number"
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.index ["lease_id"], name: "index_invoices_on_lease_id"
  end

  create_table "leases", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_months"
    t.decimal "enhancement_amount", precision: 10, scale: 2
    t.integer "enhancement_period_months"
    t.integer "enhancement_type", default: 0
    t.bigint "property_id", null: false
    t.text "property_schedule"
    t.integer "quantity", default: 1, null: false
    t.bigint "renewed_from_id"
    t.decimal "rent_amount"
    t.integer "security_deposit_type", default: 0, null: false
    t.decimal "security_deposit_value", precision: 12, scale: 2
    t.date "start_date"
    t.string "tax_name"
    t.decimal "tax_rate", precision: 5, scale: 2
    t.bigint "tenant_id", null: false
    t.date "terminated_on"
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_leases_on_property_id"
    t.index ["renewed_from_id"], name: "index_leases_on_renewed_from_id"
    t.index ["tenant_id"], name: "index_leases_on_tenant_id"
  end

  create_table "line_items", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2
    t.string "category"
    t.datetime "created_at", null: false
    t.bigint "invoice_id", null: false
    t.string "name"
    t.decimal "tax_rate", precision: 5, scale: 3, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_line_items_on_invoice_id"
  end

  create_table "owners", force: :cascade do |t|
    t.text "address"
    t.datetime "created_at", null: false
    t.string "credit_note_prefix"
    t.integer "credit_note_sequence", default: 0, null: false
    t.string "invoice_prefix"
    t.integer "invoice_sequence", default: 0
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "payments", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.decimal "balance", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.bigint "lease_id", null: false
    t.integer "mode"
    t.integer "payment_type", default: 0, null: false
    t.string "reference_number"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["lease_id"], name: "index_payments_on_lease_id"
  end

  create_table "properties", force: :cascade do |t|
    t.text "address"
    t.integer "capacity", default: 1, null: false
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "owner_id", null: false
    t.string "unit", default: "Unit", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_properties_on_owner_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tenants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "phone_number"
    t.datetime "updated_at", null: false
  end

  create_table "user_associations", force: :cascade do |t|
    t.bigint "associable_id", null: false
    t.string "associable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["associable_type", "associable_id"], name: "index_user_associations_on_associable"
    t.index ["user_id", "associable_type", "associable_id"], name: "index_user_associations_uniqueness", unique: true
    t.index ["user_id"], name: "index_user_associations_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "provider", null: false
    t.integer "role", default: 1, null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email"
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.bigint "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["whodunnit"], name: "index_versions_on_whodunnit"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "entries", "leases"
  add_foreign_key "invoices", "leases"
  add_foreign_key "leases", "leases", column: "renewed_from_id"
  add_foreign_key "leases", "properties"
  add_foreign_key "leases", "tenants"
  add_foreign_key "line_items", "invoices"
  add_foreign_key "payments", "leases"
  add_foreign_key "properties", "owners"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "user_associations", "users"
end
