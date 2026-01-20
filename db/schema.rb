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

ActiveRecord::Schema[8.0].define(version: 2026_01_14_185222) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "card_vehicle_mappings", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "vehicle_id", null: false
    t.bigint "integration_provider_id", null: false
    t.string "card_number", null: false
    t.string "alternate_plate"
    t.jsonb "metadata", default: {}
    t.boolean "is_active", default: true
    t.datetime "valid_from"
    t.datetime "valid_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_number"], name: "index_card_vehicle_mappings_on_card_number"
    t.index ["integration_provider_id"], name: "index_card_vehicle_mappings_on_integration_provider_id"
    t.index ["tenant_id", "integration_provider_id", "card_number"], name: "idx_card_vehicle_tenant_provider_card", unique: true
    t.index ["tenant_id"], name: "index_card_vehicle_mappings_on_tenant_id"
    t.index ["vehicle_id", "is_active"], name: "index_card_vehicle_mappings_on_vehicle_id_and_is_active"
    t.index ["vehicle_id"], name: "index_card_vehicle_mappings_on_vehicle_id"
  end

  create_table "financial_transactions", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "integration_raw_data_id"
    t.bigint "tenant_integration_configuration_id", null: false
    t.bigint "product_catalog_id"
    t.string "provider_slug", limit: 50, null: false
    t.string "card_number", limit: 50
    t.string "vehicle_plate", limit: 20
    t.datetime "transaction_date", null: false
    t.string "location_string", limit: 255
    t.decimal "location_lat", precision: 10, scale: 8
    t.decimal "location_lng", precision: 11, scale: 8
    t.decimal "quantity", precision: 10, scale: 3
    t.decimal "unit_price", precision: 10, scale: 4
    t.decimal "base_amount", precision: 10, scale: 2
    t.decimal "discount_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_amount", precision: 10, scale: 2, null: false
    t.string "currency", limit: 3, default: "EUR"
    t.string "status", limit: 20, default: "pending", null: false
    t.integer "match_confidence", default: 0
    t.text "discrepancy_flags", default: [], array: true
    t.jsonb "reconciliation_metadata", default: {}, null: false
    t.jsonb "provider_metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_financial_transactions_on_discarded_at"
    t.index ["integration_raw_data_id"], name: "index_financial_transactions_on_integration_raw_data_id"
    t.index ["product_catalog_id"], name: "index_financial_transactions_on_product_catalog_id"
    t.index ["provider_metadata"], name: "index_financial_transactions_on_provider_metadata", using: :gin
    t.index ["provider_slug", "transaction_date"], name: "idx_fin_trans_provider_date"
    t.index ["reconciliation_metadata"], name: "index_financial_transactions_on_reconciliation_metadata", using: :gin
    t.index ["status"], name: "index_financial_transactions_on_status"
    t.index ["tenant_id", "status"], name: "idx_fin_trans_tenant_status"
    t.index ["tenant_id"], name: "index_financial_transactions_on_tenant_id"
    t.index ["tenant_integration_configuration_id"], name: "idx_on_tenant_integration_configuration_id_433ca6afed"
    t.index ["vehicle_plate", "transaction_date"], name: "idx_fin_trans_vehicle_date"
  end

  create_table "fuel_types", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.integer "energy_group", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_fuel_types_on_code", unique: true
    t.index ["name"], name: "index_fuel_types_on_name", unique: true
  end

  create_table "integration_auth_schemas", force: :cascade do |t|
    t.bigint "integration_provider_id", null: false
    t.jsonb "auth_fields", default: {}, null: false
    t.jsonb "example_credentials", default: {}
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["integration_provider_id"], name: "idx_auth_schemas_active_provider", unique: true, where: "(is_active = true)"
    t.index ["integration_provider_id"], name: "index_integration_auth_schemas_on_integration_provider_id"
    t.index ["is_active"], name: "index_integration_auth_schemas_on_is_active"
  end

  create_table "integration_categories", force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.string "slug", limit: 50, null: false
    t.text "description"
    t.string "icon", limit: 50
    t.integer "display_order", default: 999, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["display_order"], name: "index_integration_categories_on_display_order"
    t.index ["is_active"], name: "index_integration_categories_on_is_active"
    t.index ["slug"], name: "index_integration_categories_on_slug", unique: true
  end

  create_table "integration_features", force: :cascade do |t|
    t.bigint "integration_provider_id", null: false
    t.string "feature_key", limit: 50, null: false
    t.string "feature_name", limit: 100, null: false
    t.text "feature_description"
    t.integer "display_order", default: 999, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["display_order"], name: "index_integration_features_on_display_order"
    t.index ["feature_key"], name: "index_integration_features_on_feature_key"
    t.index ["integration_provider_id", "feature_key"], name: "idx_features_provider_key", unique: true
    t.index ["integration_provider_id"], name: "index_integration_features_on_integration_provider_id"
    t.index ["is_active"], name: "index_integration_features_on_is_active"
  end

  create_table "integration_providers", force: :cascade do |t|
    t.bigint "integration_category_id", null: false
    t.string "name", limit: 100, null: false
    t.string "slug", limit: 50, null: false
    t.string "api_base_url", limit: 500
    t.text "description"
    t.string "logo_url", limit: 500
    t.string "website_url", limit: 500
    t.string "status", limit: 20, default: "active", null: false
    t.boolean "is_premium", default: false, null: false
    t.integer "display_order", default: 999, null: false
    t.boolean "is_active", default: true, null: false
    t.integer "connection_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["connection_type"], name: "index_integration_providers_on_connection_type"
    t.index ["display_order"], name: "index_integration_providers_on_display_order"
    t.index ["integration_category_id"], name: "index_integration_providers_on_integration_category_id"
    t.index ["is_active"], name: "index_integration_providers_on_is_active"
    t.index ["is_premium"], name: "index_integration_providers_on_is_premium"
    t.index ["slug"], name: "index_integration_providers_on_slug", unique: true
    t.index ["status"], name: "index_integration_providers_on_status"
  end

  create_table "integration_raw_data", force: :cascade do |t|
    t.bigint "integration_sync_execution_id", null: false
    t.bigint "tenant_integration_configuration_id", null: false
    t.string "provider_slug", limit: 50, null: false
    t.string "feature_key", limit: 50, null: false
    t.string "external_id", limit: 255, null: false
    t.jsonb "raw_data", null: false
    t.string "processing_status", limit: 20, default: "pending", null: false
    t.string "normalized_record_type", limit: 50
    t.bigint "normalized_record_id"
    t.text "normalization_error"
    t.datetime "normalized_at"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "last_retry_at"
    t.datetime "discarded_at"
    t.integer "retry_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_integration_raw_data_on_discarded_at"
    t.index ["external_id"], name: "index_integration_raw_data_on_external_id"
    t.index ["integration_sync_execution_id", "processing_status"], name: "idx_raw_data_exec_status"
    t.index ["integration_sync_execution_id"], name: "idx_raw_data_execution"
    t.index ["last_retry_at"], name: "index_integration_raw_data_on_last_retry_at"
    t.index ["metadata"], name: "index_integration_raw_data_on_metadata", using: :gin
    t.index ["normalized_record_type", "normalized_record_id"], name: "idx_raw_data_normalized"
    t.index ["processing_status"], name: "index_integration_raw_data_on_processing_status"
    t.index ["retry_count"], name: "index_integration_raw_data_on_retry_count"
    t.index ["tenant_integration_configuration_id", "external_id", "feature_key"], name: "idx_raw_data_config_external_feature", unique: true, where: "(discarded_at IS NULL)"
    t.index ["tenant_integration_configuration_id", "processing_status", "created_at"], name: "idx_raw_data_config_status_date"
    t.index ["tenant_integration_configuration_id", "provider_slug", "feature_key", "external_id"], name: "idx_raw_data_unique", unique: true
    t.index ["tenant_integration_configuration_id"], name: "idx_raw_data_config"
  end

  create_table "integration_sync_executions", force: :cascade do |t|
    t.bigint "tenant_integration_configuration_id", null: false
    t.string "feature_key", limit: 50, null: false
    t.string "trigger_type", limit: 20, default: "manual", null: false
    t.string "status", limit: 20, default: "running", null: false
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.integer "duration_seconds"
    t.integer "records_fetched", default: 0, null: false
    t.integer "records_processed", default: 0, null: false
    t.integer "records_failed", default: 0, null: false
    t.integer "records_skipped", default: 0, null: false
    t.integer "duplicate_records", default: 0, null: false
    t.text "error_message"
    t.jsonb "metadata", default: {}, null: false
    t.jsonb "duplicate_external_ids", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key"], name: "index_integration_sync_executions_on_feature_key"
    t.index ["started_at"], name: "index_integration_sync_executions_on_started_at"
    t.index ["status"], name: "index_integration_sync_executions_on_status"
    t.index ["tenant_integration_configuration_id", "started_at"], name: "idx_sync_exec_config_date"
    t.index ["tenant_integration_configuration_id"], name: "idx_sync_exec_config"
    t.index ["trigger_type"], name: "index_integration_sync_executions_on_trigger_type"
  end

  create_table "product_catalogs", force: :cascade do |t|
    t.bigint "integration_provider_id", null: false
    t.bigint "fuel_type_id"
    t.string "product_code", null: false
    t.string "product_name", null: false
    t.string "energy_type", null: false
    t.string "fuel_type"
    t.text "description"
    t.jsonb "metadata", default: {}
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["energy_type"], name: "index_product_catalogs_on_energy_type"
    t.index ["fuel_type_id"], name: "index_product_catalogs_on_fuel_type_id"
    t.index ["integration_provider_id", "product_code", "product_name"], name: "idx_product_catalog_provider_code_name", unique: true
    t.index ["integration_provider_id"], name: "index_product_catalogs_on_integration_provider_id"
  end

  create_table "soft_delete_audit_logs", force: :cascade do |t|
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.string "performed_by_type"
    t.bigint "performed_by_id"
    t.string "action", limit: 20, null: false
    t.jsonb "context", default: {}, null: false
    t.integer "cascade_count", default: 0, null: false
    t.integer "nullify_count", default: 0, null: false
    t.boolean "can_restore", default: true, null: false
    t.string "restore_complexity", limit: 20
    t.datetime "performed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_soft_delete_audit_logs_on_action"
    t.index ["can_restore"], name: "index_soft_delete_audit_logs_on_can_restore"
    t.index ["cascade_count"], name: "index_audit_logs_on_high_cascade", where: "(cascade_count > 10)"
    t.index ["performed_at"], name: "index_soft_delete_audit_logs_on_performed_at"
    t.index ["performed_by_type", "performed_by_id", "performed_at"], name: "index_audit_logs_on_user_date"
    t.index ["performed_by_type", "performed_by_id"], name: "index_soft_delete_audit_logs_on_performed_by"
    t.index ["record_type", "action", "performed_at"], name: "index_audit_logs_on_record_type_action_date"
    t.index ["record_type", "record_id"], name: "index_soft_delete_audit_logs_on_record"
  end

  create_table "tenant_integration_configurations", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "integration_provider_id", null: false
    t.jsonb "credentials"
    t.boolean "is_active", default: false, null: false
    t.datetime "activated_at"
    t.string "sync_frequency", limit: 20, default: "daily", null: false
    t.integer "sync_hour", default: 2, null: false
    t.integer "sync_day_of_week"
    t.string "sync_day_of_month", limit: 20
    t.jsonb "enabled_features", default: [], null: false
    t.jsonb "sync_config", default: {}, null: false
    t.datetime "last_sync_at"
    t.string "last_sync_status", limit: 20
    t.text "last_sync_error"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["integration_provider_id"], name: "idx_tenant_config_provider"
    t.index ["is_active"], name: "index_tenant_integration_configurations_on_is_active"
    t.index ["last_sync_at"], name: "index_tenant_integration_configurations_on_last_sync_at"
    t.index ["last_sync_status"], name: "index_tenant_integration_configurations_on_last_sync_status"
    t.index ["sync_day_of_week"], name: "index_tenant_integration_configurations_on_sync_day_of_week"
    t.index ["sync_frequency"], name: "index_tenant_integration_configurations_on_sync_frequency"
    t.index ["sync_hour"], name: "index_tenant_integration_configurations_on_sync_hour"
    t.index ["tenant_id", "integration_provider_id"], name: "idx_tenant_provider_unique", unique: true
    t.index ["tenant_id"], name: "idx_tenant_config_tenant"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.string "slug", limit: 100, null: false
    t.string "email", limit: 255
    t.string "status", limit: 20, default: "active", null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_tenants_on_created_at"
    t.index ["slug"], name: "index_tenants_on_slug", unique: true
    t.index ["status"], name: "index_tenants_on_status"
  end

  create_table "vehicle_electric_charges", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "vehicle_id", null: false
    t.bigint "integration_raw_data_id"
    t.datetime "charge_start_time", null: false
    t.datetime "charge_end_time"
    t.integer "duration_minutes"
    t.decimal "cost", precision: 10, scale: 2
    t.decimal "location_lat", precision: 10, scale: 8
    t.decimal "location_lng", precision: 11, scale: 8
    t.string "charge_type", limit: 10
    t.decimal "start_soc_percent", precision: 5, scale: 2
    t.decimal "end_soc_percent", precision: 5, scale: 2
    t.decimal "energy_consumed_kwh", precision: 10, scale: 3
    t.decimal "peak_power_kw", precision: 10, scale: 3
    t.decimal "odometer_km", precision: 12, scale: 2
    t.boolean "is_estimated", default: false, null: false
    t.integer "max_ac_voltage"
    t.jsonb "provider_metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "financial_transaction_id"
    t.integer "source", default: 0, null: false
    t.boolean "is_reconciled", default: false, null: false
    t.datetime "discarded_at"
    t.index ["charge_start_time"], name: "index_vehicle_electric_charges_on_charge_start_time"
    t.index ["charge_type"], name: "index_vehicle_electric_charges_on_charge_type"
    t.index ["discarded_at"], name: "index_vehicle_electric_charges_on_discarded_at"
    t.index ["financial_transaction_id"], name: "index_vehicle_electric_charges_on_financial_transaction_id"
    t.index ["integration_raw_data_id"], name: "idx_charges_raw_unique", unique: true
    t.index ["is_estimated"], name: "index_vehicle_electric_charges_on_is_estimated"
    t.index ["source", "is_reconciled"], name: "idx_charges_source_reconciled"
    t.index ["tenant_id", "charge_start_time"], name: "idx_charges_tenant_date"
    t.index ["tenant_id"], name: "index_vehicle_electric_charges_on_tenant_id"
    t.index ["vehicle_id", "charge_start_time", "energy_consumed_kwh"], name: "idx_unique_telemetry_charge", unique: true, where: "(source = ANY (ARRAY[0, 3]))"
    t.index ["vehicle_id", "charge_start_time"], name: "idx_charges_vehicle_date"
    t.index ["vehicle_id"], name: "index_vehicle_electric_charges_on_vehicle_id"
  end

  create_table "vehicle_kms", force: :cascade do |t|
    t.bigint "vehicle_id", null: false
    t.date "input_date", null: false
    t.integer "km_reported", null: false
    t.integer "km_normalized"
    t.integer "status", default: 0, null: false
    t.string "source_record_type"
    t.bigint "source_record_id"
    t.text "correction_notes"
    t.jsonb "conflict_reasons", default: {}
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_vehicle_kms_on_discarded_at"
    t.index ["source_record_type", "source_record_id"], name: "index_vehicle_kms_on_source_record"
    t.index ["status"], name: "index_vehicle_kms_on_status"
    t.index ["vehicle_id"], name: "index_vehicle_kms_on_vehicle_id"
  end

  create_table "vehicle_provider_mappings", force: :cascade do |t|
    t.bigint "vehicle_id", null: false
    t.bigint "tenant_integration_configuration_id", null: false
    t.string "external_vehicle_id", limit: 100, null: false
    t.string "external_vehicle_name", limit: 255
    t.boolean "is_active", default: true, null: false
    t.datetime "mapped_at"
    t.datetime "last_sync_at"
    t.datetime "valid_from", null: false
    t.datetime "valid_until"
    t.jsonb "external_metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_vehicle_provider_mappings_on_discarded_at"
    t.index ["external_vehicle_id"], name: "index_vehicle_provider_mappings_on_external_vehicle_id"
    t.index ["is_active"], name: "index_vehicle_provider_mappings_on_is_active"
    t.index ["last_sync_at"], name: "index_vehicle_provider_mappings_on_last_sync_at"
    t.index ["tenant_integration_configuration_id", "external_vehicle_id", "valid_from", "valid_until"], name: "idx_vpm_history_lookup"
    t.index ["tenant_integration_configuration_id", "external_vehicle_id"], name: "idx_vpm_config_external_active", unique: true, where: "(is_active = true)"
    t.index ["tenant_integration_configuration_id"], name: "idx_vpm_config"
    t.index ["vehicle_id", "tenant_integration_configuration_id", "is_active"], name: "idx_vpm_vehicle_config_active", unique: true, where: "(is_active = true)"
    t.index ["vehicle_id"], name: "index_vehicle_provider_mappings_on_vehicle_id"
  end

  create_table "vehicle_refuelings", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "vehicle_id", null: false
    t.bigint "integration_raw_data_id"
    t.bigint "fuel_type_id"
    t.datetime "refueling_date", null: false
    t.decimal "location_lat", precision: 10, scale: 8
    t.decimal "location_lng", precision: 11, scale: 8
    t.decimal "volume_liters", precision: 10, scale: 2, null: false
    t.decimal "cost", precision: 10, scale: 2
    t.string "currency", limit: 3
    t.decimal "odometer_km", precision: 12, scale: 2
    t.string "confidence_level", limit: 100
    t.boolean "is_estimated", default: false, null: false
    t.decimal "tank_capacity_liters", precision: 10, scale: 2
    t.jsonb "provider_metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "financial_transaction_id"
    t.integer "source", default: 0, null: false
    t.boolean "is_reconciled", default: false, null: false
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_vehicle_refuelings_on_discarded_at"
    t.index ["financial_transaction_id"], name: "index_vehicle_refuelings_on_financial_transaction_id"
    t.index ["fuel_type_id"], name: "index_vehicle_refuelings_on_fuel_type_id"
    t.index ["integration_raw_data_id"], name: "idx_refuelings_raw_unique", unique: true
    t.index ["is_estimated"], name: "index_vehicle_refuelings_on_is_estimated"
    t.index ["refueling_date"], name: "index_vehicle_refuelings_on_refueling_date"
    t.index ["source", "is_reconciled"], name: "idx_refuelings_source_reconciled"
    t.index ["tenant_id", "refueling_date"], name: "idx_refuelings_tenant_date"
    t.index ["tenant_id"], name: "index_vehicle_refuelings_on_tenant_id"
    t.index ["vehicle_id", "refueling_date", "volume_liters"], name: "idx_unique_telemetry_refueling", unique: true, where: "(source = ANY (ARRAY[0, 3]))"
    t.index ["vehicle_id", "refueling_date"], name: "idx_refuelings_vehicle_date"
    t.index ["vehicle_id"], name: "index_vehicle_refuelings_on_vehicle_id"
  end

  create_table "vehicles", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "name", limit: 255, null: false
    t.string "license_plate", limit: 20, null: false
    t.string "vin", limit: 17
    t.string "brand", limit: 100
    t.string "model", limit: 100
    t.integer "year"
    t.string "vehicle_type", limit: 50
    t.string "fuel_type", limit: 50
    t.boolean "is_electric", default: false, null: false
    t.decimal "tank_capacity_liters", precision: 10, scale: 2
    t.decimal "battery_capacity_kwh", precision: 10, scale: 2
    t.decimal "initial_odometer_km", precision: 12, scale: 2
    t.decimal "current_odometer_km", precision: 12, scale: 2
    t.string "status", limit: 20, default: "active", null: false
    t.date "acquisition_date"
    t.date "last_maintenance_date"
    t.date "next_maintenance_date"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "discarded_at"
    t.index ["discarded_at"], name: "index_vehicles_on_discarded_at"
    t.index ["fuel_type"], name: "index_vehicles_on_fuel_type"
    t.index ["is_electric"], name: "index_vehicles_on_is_electric"
    t.index ["status"], name: "index_vehicles_on_status"
    t.index ["tenant_id", "license_plate"], name: "idx_vehicles_tenant_plate", unique: true
    t.index ["tenant_id", "status"], name: "idx_vehicles_tenant_status"
    t.index ["tenant_id"], name: "index_vehicles_on_tenant_id"
    t.index ["vehicle_type"], name: "index_vehicles_on_vehicle_type"
    t.index ["vin"], name: "index_vehicles_on_vin", unique: true, where: "(vin IS NOT NULL)"
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

  add_foreign_key "card_vehicle_mappings", "integration_providers"
  add_foreign_key "card_vehicle_mappings", "tenants"
  add_foreign_key "card_vehicle_mappings", "vehicles"
  add_foreign_key "financial_transactions", "integration_raw_data", column: "integration_raw_data_id"
  add_foreign_key "financial_transactions", "product_catalogs"
  add_foreign_key "financial_transactions", "tenant_integration_configurations"
  add_foreign_key "financial_transactions", "tenants"
  add_foreign_key "integration_auth_schemas", "integration_providers"
  add_foreign_key "integration_features", "integration_providers"
  add_foreign_key "integration_providers", "integration_categories"
  add_foreign_key "integration_raw_data", "integration_sync_executions"
  add_foreign_key "integration_raw_data", "tenant_integration_configurations"
  add_foreign_key "integration_sync_executions", "tenant_integration_configurations"
  add_foreign_key "product_catalogs", "fuel_types"
  add_foreign_key "product_catalogs", "integration_providers"
  add_foreign_key "tenant_integration_configurations", "integration_providers"
  add_foreign_key "tenant_integration_configurations", "tenants"
  add_foreign_key "vehicle_electric_charges", "financial_transactions"
  add_foreign_key "vehicle_electric_charges", "integration_raw_data", column: "integration_raw_data_id"
  add_foreign_key "vehicle_electric_charges", "tenants"
  add_foreign_key "vehicle_electric_charges", "vehicles"
  add_foreign_key "vehicle_kms", "vehicles"
  add_foreign_key "vehicle_provider_mappings", "tenant_integration_configurations"
  add_foreign_key "vehicle_provider_mappings", "vehicles"
  add_foreign_key "vehicle_refuelings", "financial_transactions"
  add_foreign_key "vehicle_refuelings", "fuel_types"
  add_foreign_key "vehicle_refuelings", "integration_raw_data", column: "integration_raw_data_id"
  add_foreign_key "vehicle_refuelings", "tenants"
  add_foreign_key "vehicle_refuelings", "vehicles"
  add_foreign_key "vehicles", "tenants"
end
