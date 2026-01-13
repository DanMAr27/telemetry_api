class CreateFuelTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :fuel_types do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.integer :energy_group, default: 0

      t.timestamps
    end
    add_index :fuel_types, :name, unique: true
    add_index :fuel_types, :code, unique: true
  end
end
