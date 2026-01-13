# db/migrate/20260109100118_add_financial_fields_to_vehicle_data.rb
class AddFinancialFieldsToVehicleData < ActiveRecord::Migration[8.0]
  def change
    # === VEHICLE_REFUELINGS ===
    add_reference :vehicle_refuelings, :financial_transaction,
                  foreign_key: true,
                  index: true
    add_column :vehicle_refuelings, :source, :integer, default: 0, null: false   # 0=telemetry, 1=financial, 2=manual, 3=merged
    add_column :vehicle_refuelings, :is_reconciled, :boolean, default: false, null: false
    add_index :vehicle_refuelings, [ :source, :is_reconciled ],
              name: 'idx_refuelings_source_reconciled'
    add_index :vehicle_refuelings,
              [ :vehicle_id, :refueling_date, :volume_liters ],
              unique: true,
              where: "source IN (0, 3)",  # telemetry=0, merged=3
              name: 'idx_unique_telemetry_refueling'

    # === VEHICLE_ELECTRIC_CHARGES ===
    add_reference :vehicle_electric_charges, :financial_transaction,
                  foreign_key: true,
                  index: true
    add_column :vehicle_electric_charges, :source, :integer, default: 0, null: false     # 0=telemetry, 1=financial, 2=manual, 3=merged
    add_column :vehicle_electric_charges, :is_reconciled, :boolean, default: false, null: false
    add_index :vehicle_electric_charges, [ :source, :is_reconciled ],
              name: 'idx_charges_source_reconciled'
    add_index :vehicle_electric_charges,
              [ :vehicle_id, :charge_start_time, :energy_consumed_kwh ],
              unique: true,
              where: "source IN (0, 3)",  # telemetry=0, merged=3
              name: 'idx_unique_telemetry_charge'
  end
end
