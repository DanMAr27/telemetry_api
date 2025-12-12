class CreateRefuels < ActiveRecord::Migration[7.0]
  def change
    create_table :refuels do |t|
      t.references :vehicle, null: false, foreign_key: true

      # Identificación del proveedor
      t.string :external_id, null: false
      t.string :provider_name, null: false

      # Datos normalizados del repostaje
      t.datetime :refuel_date, null: false
      t.decimal :volume_liters, precision: 10, scale: 2
      t.decimal :cost, precision: 10, scale: 2
      t.string :currency_code, limit: 3

      # Ubicación
      t.decimal :location_lat, precision: 10, scale: 6
      t.decimal :location_lng, precision: 10, scale: 6

      # Datos del vehículo en el momento del repostaje
      t.decimal :odometer_km, precision: 12, scale: 2
      t.decimal :tank_capacity_liters, precision: 10, scale: 2
      t.decimal :distance_since_last_refuel_km, precision: 10, scale: 2

      # Metadatos
      t.string :confidence_level
      t.string :product_type

      # JSON original del proveedor (para auditoría/debugging)
      t.jsonb :raw_data, default: {}

      t.timestamps
    end

    # Evitar duplicados: un vehículo no puede tener dos veces el mismo external_id del mismo proveedor
    add_index :refuels, [ :vehicle_id, :external_id, :provider_name ],
              unique: true,
              name: 'idx_refuels_vehicle_external'

    add_index :refuels, :refuel_date
    add_index :refuels, :provider_name
    add_index :refuels, [ :location_lat, :location_lng ], name: 'idx_refuels_location'
  end
end
