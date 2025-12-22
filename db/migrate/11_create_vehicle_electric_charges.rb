# db/migrate/create_vehicle_electric_charges.rb
class CreateVehicleElectricCharges < ActiveRecord::Migration[7.0]
  def change
    create_table :vehicle_electric_charges do |t|
      t.references :tenant, null: false, foreign_key: true, index: true
      t.references :vehicle, null: false, foreign_key: true, index: true
      t.references :integration_raw_data,
                   foreign_key: true,
                   index: { unique: true, name: 'idx_charges_raw_unique' }
      t.datetime :charge_start_time, null: false
      t.datetime :charge_end_time
      t.integer :duration_minutes
      t.decimal :location_lat, precision: 10, scale: 8
      t.decimal :location_lng, precision: 11, scale: 8
      t.string :charge_type, limit: 10
      t.decimal :start_soc_percent, precision: 5, scale: 2
      t.decimal :end_soc_percent, precision: 5, scale: 2
      t.decimal :energy_consumed_kwh, precision: 10, scale: 3
      t.decimal :peak_power_kw, precision: 10, scale: 3
      t.decimal :odometer_km, precision: 12, scale: 2
      t.boolean :is_estimated, default: false, null: false
      t.integer :max_ac_voltage
      t.jsonb :provider_metadata, default: {}, null: false
      t.timestamps
    end
    add_index :vehicle_electric_charges, :charge_start_time
    add_index :vehicle_electric_charges, [ :tenant_id, :charge_start_time ], name: 'idx_charges_tenant_date'
    add_index :vehicle_electric_charges, [ :vehicle_id, :charge_start_time ], name: 'idx_charges_vehicle_date'
    add_index :vehicle_electric_charges, :charge_type
    add_index :vehicle_electric_charges, :is_estimated
  end
end
