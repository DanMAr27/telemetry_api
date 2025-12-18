# db/migrate/create_integration_sync_executions.rb
class CreateIntegrationSyncExecutions < ActiveRecord::Migration[7.0]
  def change
    create_table :integration_sync_executions do |t|
      t.references :tenant_integration_configuration,
                   null: false,
                   foreign_key: true,
                   index: { name: 'idx_sync_exec_config' }
      t.string :feature_key, null: false, limit: 50
      t.string :trigger_type, null: false, limit: 20, default: 'manual'
      t.string :status, null: false, limit: 20, default: 'running'
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.integer :duration_seconds
      t.integer :records_fetched, default: 0, null: false
      t.integer :records_processed, default: 0, null: false
      t.integer :records_failed, default: 0, null: false
      t.integer :records_skipped, default: 0, null: false
      t.text :error_message
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end
    add_index :integration_sync_executions, :feature_key
    add_index :integration_sync_executions, :status
    add_index :integration_sync_executions, :trigger_type
    add_index :integration_sync_executions, :started_at
    add_index :integration_sync_executions,
              [ :tenant_integration_configuration_id, :started_at ],
              name: 'idx_sync_exec_config_date'
  end
end
