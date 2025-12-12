class CreateTelemetrySyncLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :telemetry_sync_logs do |t|
      t.references :telemetry_credential, null: false, foreign_key: true
      t.references :vehicle, foreign_key: true # nullable: puede ser sync de toda la flota

      # Tipo de sincronización
      t.string :sync_type, null: false # 'refuels', 'charges', 'full', 'odometer'

      # Estado
      t.string :status, null: false # 'success', 'error', 'partial'

      # Estadísticas
      t.integer :records_processed, default: 0
      t.integer :records_created, default: 0
      t.integer :records_updated, default: 0
      t.integer :records_skipped, default: 0

      # Errores
      t.text :error_message
      t.jsonb :error_details, default: {}

      # Timing
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :telemetry_sync_logs, :status
    add_index :telemetry_sync_logs, :sync_type
    add_index :telemetry_sync_logs, :started_at
    add_index :telemetry_sync_logs, [ :telemetry_credential_id, :created_at ],
              name: 'idx_sync_logs_credential_date'
  end
end
