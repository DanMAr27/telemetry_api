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

ActiveRecord::Schema[8.0].define(version: 10) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.string "tax_id"
    t.string "email"
    t.string "phone"
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_companies_on_is_active"
    t.index ["tax_id"], name: "index_companies_on_tax_id", unique: true
  end

  create_table "electric_charges", force: :cascade do |t|
    t.bigint "vehicle_id", null: false
    t.string "external_id", null: false
    t.string "provider_name", null: false
    t.datetime "start_time", null: false
    t.integer "duration_minutes"
    t.decimal "energy_consumed_kwh", precision: 10, scale: 3
    t.decimal "start_soc_percent", precision: 5, scale: 2
    t.decimal "end_soc_percent", precision: 5, scale: 2
    t.string "charge_type"
    t.boolean "charge_is_estimated"
    t.decimal "location_lat", precision: 10, scale: 6
    t.decimal "location_lng", precision: 10, scale: 6
    t.decimal "odometer_km", precision: 12, scale: 2
    t.decimal "peak_power_kw", precision: 10, scale: 3
    t.decimal "measured_charger_energy_in_kwh", precision: 10, scale: 3
    t.decimal "measured_battery_energy_in_kwh", precision: 10, scale: 3
    t.jsonb "raw_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["charge_type"], name: "index_electric_charges_on_charge_type"
    t.index ["location_lat", "location_lng"], name: "idx_charges_location"
    t.index ["provider_name"], name: "index_electric_charges_on_provider_name"
    t.index ["start_time"], name: "index_electric_charges_on_start_time"
    t.index ["vehicle_id", "external_id", "provider_name"], name: "idx_charges_vehicle_external", unique: true
    t.index ["vehicle_id"], name: "index_electric_charges_on_vehicle_id"
  end

  create_table "refuels", force: :cascade do |t|
    t.bigint "vehicle_id", null: false
    t.string "external_id", null: false
    t.string "provider_name", null: false
    t.datetime "refuel_date", null: false
    t.decimal "volume_liters", precision: 10, scale: 2
    t.decimal "cost", precision: 10, scale: 2
    t.string "currency_code", limit: 3
    t.decimal "location_lat", precision: 10, scale: 6
    t.decimal "location_lng", precision: 10, scale: 6
    t.decimal "odometer_km", precision: 12, scale: 2
    t.decimal "tank_capacity_liters", precision: 10, scale: 2
    t.decimal "distance_since_last_refuel_km", precision: 10, scale: 2
    t.string "confidence_level"
    t.string "product_type"
    t.jsonb "raw_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_lat", "location_lng"], name: "idx_refuels_location"
    t.index ["provider_name"], name: "index_refuels_on_provider_name"
    t.index ["refuel_date"], name: "index_refuels_on_refuel_date"
    t.index ["vehicle_id", "external_id", "provider_name"], name: "idx_refuels_vehicle_external", unique: true
    t.index ["vehicle_id"], name: "index_refuels_on_vehicle_id"
  end

  create_table "telemetry_credentials", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "telemetry_provider_id", null: false
    t.text "encrypted_credentials"
    t.string "encrypted_credentials_iv"
    t.boolean "is_active", default: true
    t.datetime "last_sync_at"
    t.datetime "last_successful_sync_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "telemetry_provider_id"], name: "idx_credentials_company_provider", unique: true
    t.index ["company_id"], name: "index_telemetry_credentials_on_company_id"
    t.index ["is_active"], name: "index_telemetry_credentials_on_is_active"
    t.index ["last_sync_at"], name: "index_telemetry_credentials_on_last_sync_at"
    t.index ["telemetry_provider_id"], name: "index_telemetry_credentials_on_telemetry_provider_id"
  end

  create_table "telemetry_normalization_errors", force: :cascade do |t|
    t.bigint "telemetry_sync_log_id", null: false
    t.string "error_type", null: false
    t.text "error_message", null: false
    t.jsonb "raw_data", null: false
    t.string "provider_name"
    t.string "data_type"
    t.boolean "resolved", default: false
    t.datetime "resolved_at"
    t.text "resolution_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_telemetry_normalization_errors_on_created_at"
    t.index ["error_type"], name: "index_telemetry_normalization_errors_on_error_type"
    t.index ["provider_name"], name: "index_telemetry_normalization_errors_on_provider_name"
    t.index ["resolved"], name: "index_telemetry_normalization_errors_on_resolved"
    t.index ["telemetry_sync_log_id"], name: "index_telemetry_normalization_errors_on_telemetry_sync_log_id"
  end

  create_table "telemetry_providers", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "api_base_url"
    t.boolean "is_active", default: true
    t.jsonb "configuration_schema", default: {}
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_telemetry_providers_on_is_active"
    t.index ["slug"], name: "index_telemetry_providers_on_slug", unique: true
  end

  create_table "telemetry_sync_logs", force: :cascade do |t|
    t.bigint "telemetry_credential_id", null: false
    t.bigint "vehicle_id"
    t.string "sync_type", null: false
    t.string "status", null: false
    t.integer "records_processed", default: 0
    t.integer "records_created", default: 0
    t.integer "records_updated", default: 0
    t.integer "records_skipped", default: 0
    t.text "error_message"
    t.jsonb "error_details", default: {}
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["started_at"], name: "index_telemetry_sync_logs_on_started_at"
    t.index ["status"], name: "index_telemetry_sync_logs_on_status"
    t.index ["sync_type"], name: "index_telemetry_sync_logs_on_sync_type"
    t.index ["telemetry_credential_id", "created_at"], name: "idx_sync_logs_credential_date"
    t.index ["telemetry_credential_id"], name: "index_telemetry_sync_logs_on_telemetry_credential_id"
    t.index ["vehicle_id"], name: "index_telemetry_sync_logs_on_vehicle_id"
  end

  create_table "vehicle_telemetry_configs", force: :cascade do |t|
    t.bigint "vehicle_id", null: false
    t.bigint "telemetry_credential_id", null: false
    t.string "external_device_id", null: false
    t.string "sync_frequency", default: "daily"
    t.jsonb "data_types", default: ["refuels", "charges", "odometer"]
    t.boolean "is_active", default: true
    t.datetime "last_sync_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_device_id"], name: "index_vehicle_telemetry_configs_on_external_device_id"
    t.index ["is_active"], name: "index_vehicle_telemetry_configs_on_is_active"
    t.index ["telemetry_credential_id"], name: "index_vehicle_telemetry_configs_on_telemetry_credential_id"
    t.index ["vehicle_id"], name: "index_vehicle_telemetry_configs_on_vehicle_id"
  end

  create_table "vehicles", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "license_plate", null: false
    t.string "vin"
    t.string "brand"
    t.string "model"
    t.integer "year"
    t.string "fuel_type"
    t.decimal "tank_capacity_liters", precision: 10, scale: 2
    t.decimal "battery_capacity_kwh", precision: 10, scale: 2
    t.boolean "is_active", default: true
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "license_plate"], name: "index_vehicles_on_company_id_and_license_plate", unique: true
    t.index ["company_id"], name: "index_vehicles_on_company_id"
    t.index ["fuel_type"], name: "index_vehicles_on_fuel_type"
    t.index ["is_active"], name: "index_vehicles_on_is_active"
    t.index ["vin"], name: "index_vehicles_on_vin"
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "electric_charges", "vehicles"
  add_foreign_key "refuels", "vehicles"
  add_foreign_key "telemetry_credentials", "companies"
  add_foreign_key "telemetry_credentials", "telemetry_providers"
  add_foreign_key "telemetry_normalization_errors", "telemetry_sync_logs"
  add_foreign_key "telemetry_sync_logs", "telemetry_credentials"
  add_foreign_key "telemetry_sync_logs", "vehicles"
  add_foreign_key "vehicle_telemetry_configs", "telemetry_credentials"
  add_foreign_key "vehicle_telemetry_configs", "vehicles"
  add_foreign_key "vehicles", "companies"
end
