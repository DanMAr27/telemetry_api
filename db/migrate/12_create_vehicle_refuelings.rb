# db/migrate/create_vehicle_refuelings.rb
class CreateVehicleRefuelings < ActiveRecord::Migration[7.0]
  def change
    create_table :vehicle_refuelings do |t|
      t.references :tenant, null: false, foreign_key: true, index: true
      t.references :vehicle, null: false, foreign_key: true, index: true
      t.references :integration_raw_data,
                   foreign_key: true,
                   index: { unique: true, name: 'idx_refuelings_raw_unique' }
      t.datetime :refueling_date, null: false
      t.decimal :location_lat, precision: 10, scale: 8
      t.decimal :location_lng, precision: 11, scale: 8
      t.decimal :volume_liters, precision: 10, scale: 2, null: false
      t.decimal :cost, precision: 10, scale: 2
      t.string :currency, limit: 3
      t.decimal :odometer_km, precision: 12, scale: 2
      t.string :fuel_type, limit: 50
      t.string :confidence_level, limit: 100
      t.boolean :is_estimated, default: false, null: false
      t.decimal :tank_capacity_liters, precision: 10, scale: 2
      t.jsonb :provider_metadata, default: {}, null: false
      t.timestamps
    end
    add_index :vehicle_refuelings, :refueling_date
    add_index :vehicle_refuelings, [ :tenant_id, :refueling_date ], name: 'idx_refuelings_tenant_date'
    add_index :vehicle_refuelings, [ :vehicle_id, :refueling_date ], name: 'idx_refuelings_vehicle_date'
    add_index :vehicle_refuelings, :is_estimated
  end
end
