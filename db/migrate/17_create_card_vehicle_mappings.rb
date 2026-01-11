# db/migrate/20260109151654_create_card_vehicle_mappings.rb
class CreateCardVehicleMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :card_vehicle_mappings do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :vehicle, null: false, foreign_key: true
      t.references :integration_provider, null: false, foreign_key: true
      t.string :card_number, null: false
      t.string :alternate_plate
      t.jsonb :metadata, default: {}
      t.boolean :is_active, default: true
      t.datetime :valid_from
      t.datetime :valid_until

      t.timestamps
    end
    add_index :card_vehicle_mappings,
              [ :tenant_id, :integration_provider_id, :card_number ],
              unique: true,
              name: 'idx_card_vehicle_tenant_provider_card'
    add_index :card_vehicle_mappings, :card_number
    add_index :card_vehicle_mappings, [ :vehicle_id, :is_active ]
  end
end
