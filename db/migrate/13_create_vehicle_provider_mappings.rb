# db/migrate/YYYYMMDDHHMMSS_create_vehicle_provider_mappings.rb
class CreateVehicleProviderMappings < ActiveRecord::Migration[7.0]
  def change
    create_table :vehicle_provider_mappings do |t|
      t.references :vehicle, null: false, foreign_key: true, index: true
      t.references :tenant_integration_configuration,
                   null: false,
                   foreign_key: true,
                   index: { name: 'idx_vpm_config' }
      t.string :external_vehicle_id, null: false, limit: 100
      # Nombre del vehículo en el proveedor (opcional)
      t.string :external_vehicle_name, limit: 255
      # Estado del mapeo
      t.boolean :is_active, default: true, null: false
      t.datetime :mapped_at
      t.datetime :last_sync_at
      t.jsonb :external_metadata, default: {}, null: false
      # Campos adicionales del proveedor:
      # {
      #   "device_serial": "GT8600012345",
      #   "device_type": "GO9",
      #   "groups": ["Fleet A", "Madrid"],
      #   "comment": "Instalado 2024-01-15"
      # }

      t.timestamps
    end

    # Índice ÚNICO: Un vehículo solo puede tener un mapeo activo por configuración
    add_index :vehicle_provider_mappings,
              [ :vehicle_id, :tenant_integration_configuration_id, :is_active ],
              unique: true,
              where: "is_active = true",
              name: 'idx_vpm_vehicle_config_active'

    # Índice ÚNICO: Un external_vehicle_id solo puede estar mapeado una vez por configuración
    add_index :vehicle_provider_mappings,
              [ :tenant_integration_configuration_id, :external_vehicle_id ],
              unique: true,
              name: 'idx_vpm_config_external'

    add_index :vehicle_provider_mappings, :external_vehicle_id
    add_index :vehicle_provider_mappings, :is_active
    add_index :vehicle_provider_mappings, :last_sync_at
  end
end
