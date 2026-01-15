class AddDiscardedAtToModels < ActiveRecord::Migration[8.0]
  def change
    # Renombrar deleted_at a discarded_at en integration_raw_data
    rename_column :integration_raw_data, :deleted_at, :discarded_at

    # Añadir discarded_at a financial_transactions
    add_column :financial_transactions, :discarded_at, :datetime
    add_index :financial_transactions, :discarded_at

    # Añadir discarded_at a vehicle_refuelings
    add_column :vehicle_refuelings, :discarded_at, :datetime
    add_index :vehicle_refuelings, :discarded_at

    # Añadir discarded_at a vehicle_electric_charges
    add_column :vehicle_electric_charges, :discarded_at, :datetime
    add_index :vehicle_electric_charges, :discarded_at

    # Añadir discarded_at a vehicles
    add_column :vehicles, :discarded_at, :datetime
    add_index :vehicles, :discarded_at

    # Añadir discarded_at a vehicle_provider_mappings
    add_column :vehicle_provider_mappings, :discarded_at, :datetime
    add_index :vehicle_provider_mappings, :discarded_at
  end
end
