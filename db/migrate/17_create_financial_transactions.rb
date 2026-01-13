# db/migrate/20260109093452_create_financial_transactions.rb
class CreateFinancialTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :financial_transactions do |t|
      t.references :tenant, null: false, foreign_key: true, index: true
      t.references :integration_raw_data, foreign_key: true, index: true
      t.references :tenant_integration_configuration, null: false, foreign_key: true, index: true
      t.references :product_catalog, foreign_key: true, index: true
      t.string :provider_slug, limit: 50, null: false
      t.string :card_number, limit: 50
      t.string :vehicle_plate, limit: 20
      t.datetime :transaction_date, null: false
      t.string :location_string, limit: 255
      t.decimal :location_lat, precision: 10, scale: 8
      t.decimal :location_lng, precision: 11, scale: 8
      t.decimal :quantity, precision: 10, scale: 3
      t.decimal :unit_price, precision: 10, scale: 4
      t.decimal :base_amount, precision: 10, scale: 2
      t.decimal :discount_amount, precision: 10, scale: 2, default: 0.0
      t.decimal :total_amount, precision: 10, scale: 2, null: false
      t.string :currency, limit: 3, default: 'EUR'
      t.string :status, limit: 20, default: 'pending', null: false
      t.integer :match_confidence, default: 0
      t.text :discrepancy_flags, array: true, default: []
      t.jsonb :reconciliation_metadata, default: {}, null: false
      t.jsonb :provider_metadata, default: {}, null: false
      t.timestamps
    end
    add_index :financial_transactions, [ :provider_slug, :transaction_date ],
              name: 'idx_fin_trans_provider_date'
    add_index :financial_transactions, [ :vehicle_plate, :transaction_date ],
              name: 'idx_fin_trans_vehicle_date'
    add_index :financial_transactions, [ :tenant_id, :status ],
              name: 'idx_fin_trans_tenant_status'
    add_index :financial_transactions, :status
    add_index :financial_transactions, :provider_metadata, using: :gin
    add_index :financial_transactions, :reconciliation_metadata, using: :gin
  end
end
