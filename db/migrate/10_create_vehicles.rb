# db/migrate/create_vehicles.rb
class CreateVehicles < ActiveRecord::Migration[7.0]
  def change
    create_table :vehicles do |t|
      t.references :tenant, null: false, foreign_key: true, index: true
      t.string :name, null: false, limit: 255
       t.string :license_plate, null: false, limit: 20
      t.string :vin, limit: 17
      t.string :brand, limit: 100
      t.string :model, limit: 100
      t.integer :year
      t.string :vehicle_type, limit: 50
      t.string :fuel_type, limit: 50
      t.boolean :is_electric, default: false, null: false
      t.decimal :tank_capacity_liters, precision: 10, scale: 2
      t.decimal :battery_capacity_kwh, precision: 10, scale: 2
      t.decimal :initial_odometer_km, precision: 12, scale: 2
      t.decimal :current_odometer_km, precision: 12, scale: 2
      t.string :status, null: false, limit: 20, default: 'active'
      t.date :acquisition_date
      t.date :last_maintenance_date
      t.date :next_maintenance_date
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :vehicles, [ :tenant_id, :license_plate ], unique: true, name: 'idx_vehicles_tenant_plate'
    add_index :vehicles, :vin, unique: true, where: "vin IS NOT NULL"
    add_index :vehicles, :status
    add_index :vehicles, :is_electric
    add_index :vehicles, :fuel_type
    add_index :vehicles, :vehicle_type
    add_index :vehicles, [ :tenant_id, :status ], name: 'idx_vehicles_tenant_status'
  end
end
