# db/migrate/YYYYMMDDHHMMSS_create_integration_raw_data.rb
class CreateIntegrationRawData < ActiveRecord::Migration[7.0]
  def change
    create_table :integration_raw_data do |t|
      t.references :integration_sync_execution,
                   null: false,
                   foreign_key: true,
                   index: { name: 'idx_raw_data_execution' }
      t.references :tenant_integration_configuration,
                   null: false,
                   foreign_key: true,
                   index: { name: 'idx_raw_data_config' }
      t.string :provider_slug, null: false, limit: 50
      t.string :feature_key, null: false, limit: 50
      t.string :external_id, null: false, limit: 255
      t.jsonb :raw_data, null: false
      t.string :processing_status, null: false, limit: 20, default: 'pending'
      t.string :normalized_record_type, limit: 50
      t.bigint :normalized_record_id
      t.text :normalization_error
      t.datetime :normalized_at
      t.jsonb :metadata, default: {}, null: false
      t.datetime :last_retry_at
      t.datetime :deleted_at
      t.integer :retry_count, default: 0, null: false
      t.timestamps
    end
    add_index :integration_raw_data,
              [ :tenant_integration_configuration_id, :provider_slug, :feature_key, :external_id ],
              unique: true,
              name: 'idx_raw_data_unique'
    add_index :integration_raw_data, :processing_status
    add_index :integration_raw_data, :external_id
    add_index :integration_raw_data,
              [ :normalized_record_type, :normalized_record_id ],
              name: 'idx_raw_data_normalized'
    add_index :integration_raw_data,
              [ :integration_sync_execution_id, :processing_status ],
              name: 'idx_raw_data_exec_status'
    add_index :integration_raw_data, :metadata, using: :gin
        add_index :integration_raw_data, :retry_count
    add_index :integration_raw_data, :last_retry_at
    add_index :integration_raw_data, :deleted_at
    add_index :integration_raw_data,
              [ :tenant_integration_configuration_id, :processing_status, :created_at ],
              name: 'idx_raw_data_config_status_date'
     add_index :integration_raw_data,
              [ :tenant_integration_configuration_id, :external_id, :feature_key ],
              name: 'idx_raw_data_config_external_feature',
              unique: true,
              where: "deleted_at IS NULL"
  end
end
