class CreateVehicles < ActiveRecord::Migration[7.0]
  def change
    # Si ya tienes tabla vehicles, skip esta migración
    return if table_exists?(:vehicles)

    create_table :vehicles do |t|
      t.references :company, null: false, foreign_key: true

      # Información básica
      t.string :name, null: false
      t.string :license_plate, null: false
      t.string :vin
      t.string :brand
      t.string :model
      t.integer :year

      # Tipo de vehículo
      t.string :fuel_type # combustion, electric, hybrid
      t.decimal :tank_capacity_liters, precision: 10, scale: 2
      t.decimal :battery_capacity_kwh, precision: 10, scale: 2

      # Estado
      t.boolean :is_active, default: true

      # Metadatos adicionales
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :vehicles, [ :company_id, :license_plate ], unique: true
    add_index :vehicles, :is_active
    add_index :vehicles, :fuel_type
    add_index :vehicles, :vin
  end
end
