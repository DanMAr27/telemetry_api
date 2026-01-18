class CreateVehicleKms < ActiveRecord::Migration[7.0]
  def change
    create_table :vehicle_kms do |t|
      t.references :vehicle, null: false, foreign_key: true
      t.date :input_date, null: false
      t.integer :km_reported, null: false
      t.integer :km_normalized
      t.integer :status, default: 0, null: false
      t.references :source_record, polymorphic: true, null: true
      t.text :correction_notes
      t.jsonb :conflict_reasons, default: {}
      t.datetime :discarded_at

      t.timestamps
    end
    add_index :vehicle_kms, :status
    add_index :vehicle_kms, :discarded_at
  end
end
