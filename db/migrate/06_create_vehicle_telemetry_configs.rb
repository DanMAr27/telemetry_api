class CreateVehicleTelemetryConfigs < ActiveRecord::Migration[7.0]
  def change
    create_table :vehicle_telemetry_configs do |t|
      t.references :vehicle, null: false, foreign_key: true
      t.references :telemetry_credential, null: false, foreign_key: true

      # ID del dispositivo en el sistema externo (ej: "b1B" en Geotab)
      t.string :external_device_id, null: false

      # Configuración de sincronización
      t.string :sync_frequency, default: 'daily' # hourly, daily, manual
      t.jsonb :data_types, default: [ 'refuels', 'charges', 'odometer' ]

      t.boolean :is_active, default: true
      t.datetime :last_sync_at

      t.timestamps
    end

    # Un vehículo solo puede estar asociado a un proveedor a la vez
    add_index :vehicle_telemetry_configs, :external_device_id
    add_index :vehicle_telemetry_configs, :is_active
  end
end
