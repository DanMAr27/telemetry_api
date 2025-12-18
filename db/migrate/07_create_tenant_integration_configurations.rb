class CreateTenantIntegrationConfigurations < ActiveRecord::Migration[7.0]
  def change
    create_table :tenant_integration_configurations do |t|
      t.references :tenant, null: false, foreign_key: true, index: false
      t.references :integration_provider, null: false, foreign_key: true, index: false

      t.text :encrypted_credentials
      t.string :encrypted_credentials_iv

      t.boolean :is_active, default: false, null: false
      t.datetime :activated_at

      t.string :sync_frequency, null: false, limit: 20, default: 'daily'
      t.integer :sync_hour, null: false, default: 2
      t.integer :sync_day_of_week
      t.string :sync_day_of_month, limit: 20

      t.jsonb :enabled_features, null: false, default: []
      t.jsonb :sync_config, null: false, default: {}

      t.datetime :last_sync_at
      t.string :last_sync_status, limit: 20
      t.text :last_sync_error

      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :tenant_integration_configurations,
              [ :tenant_id, :integration_provider_id ],
              unique: true,
              name: 'idx_tenant_provider_unique'
    add_index :tenant_integration_configurations, :tenant_id, name: 'idx_tenant_config_tenant'
    add_index :tenant_integration_configurations, :integration_provider_id, name: 'idx_tenant_config_provider'
    add_index :tenant_integration_configurations, :is_active
    add_index :tenant_integration_configurations, :sync_frequency
    add_index :tenant_integration_configurations, :sync_hour
    add_index :tenant_integration_configurations, :sync_day_of_week
    add_index :tenant_integration_configurations, :last_sync_at
    add_index :tenant_integration_configurations, :last_sync_status
  end
end
