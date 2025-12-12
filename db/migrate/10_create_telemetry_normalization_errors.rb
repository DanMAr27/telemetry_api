class CreateTelemetryNormalizationErrors < ActiveRecord::Migration[7.0]
  def change
    create_table :telemetry_normalization_errors do |t|
      t.references :telemetry_sync_log, null: false, foreign_key: true

      # Tipo de error
      t.string :error_type, null: false # 'validation_error', 'mapping_error', 'data_format_error'
      t.text :error_message, null: false

      # Datos que causaron el error
      t.jsonb :raw_data, null: false

      # Contexto adicional
      t.string :provider_name
      t.string :data_type # 'refuel', 'charge', 'trip'

      # Gestión del error
      t.boolean :resolved, default: false
      t.datetime :resolved_at
      t.text :resolution_notes

      t.timestamps
    end

    add_index :telemetry_normalization_errors, :error_type
    add_index :telemetry_normalization_errors, :resolved
    add_index :telemetry_normalization_errors, :provider_name
    add_index :telemetry_normalization_errors, :created_at
  end
end
