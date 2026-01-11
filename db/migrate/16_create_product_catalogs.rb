# db/migrate/20260109151618_create_product_catalogs.rb
class CreateProductCatalogs < ActiveRecord::Migration[8.0]
  def change
    create_table :product_catalogs do |t|
      t.references :integration_provider, null: false, foreign_key: true
      t.string :product_code, null: false
      t.string :product_name, null: false
      t.string :energy_type, null: false # 'fuel', 'electric', 'other'
      t.string :fuel_type # 'gasoline', 'diesel', 'lpg', 'cng', 'premium', 'bio'
      t.text :description
      t.jsonb :metadata, default: {}
      t.boolean :is_active, default: true

      t.timestamps
    end
    add_index :product_catalogs,
              [ :integration_provider_id, :product_code, :product_name ],
              unique: true,
              name: 'idx_product_catalog_provider_code_name'
    add_index :product_catalogs, :energy_type
  end
end
