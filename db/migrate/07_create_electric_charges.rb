class CreateElectricCharges < ActiveRecord::Migration[7.0]
  def change
    create_table :electric_charges do |t|
      t.references :vehicle, null: false, foreign_key: true

      # Identificación del proveedor
      t.string :external_id, null: false
      t.string :provider_name, null: false

      # Datos normalizados de la carga
      t.datetime :start_time, null: false
      t.integer :duration_minutes
      t.decimal :energy_consumed_kwh, precision: 10, scale: 3

      # Estado de la batería
      t.decimal :start_soc_percent, precision: 5, scale: 2
      t.decimal :end_soc_percent, precision: 5, scale: 2

      # Tipo de carga
      t.string :charge_type # AC, DC
      t.boolean :charge_is_estimated

      # Ubicación
      t.decimal :location_lat, precision: 10, scale: 6
      t.decimal :location_lng, precision: 10, scale: 6

      # Datos del vehículo en el momento de la carga
      t.decimal :odometer_km, precision: 12, scale: 2
      t.decimal :peak_power_kw, precision: 10, scale: 3

      # Mediciones detalladas de energía (específico de algunos proveedores)
      t.decimal :measured_charger_energy_in_kwh, precision: 10, scale: 3
      t.decimal :measured_battery_energy_in_kwh, precision: 10, scale: 3

      # JSON original del proveedor
      t.jsonb :raw_data, default: {}

      t.timestamps
    end

    # Evitar duplicados
    add_index :electric_charges, [ :vehicle_id, :external_id, :provider_name ],
              unique: true,
              name: 'idx_charges_vehicle_external'

    add_index :electric_charges, :start_time
    add_index :electric_charges, :provider_name
    add_index :electric_charges, :charge_type
    add_index :electric_charges, [ :location_lat, :location_lng ], name: 'idx_charges_location'
  end
end
