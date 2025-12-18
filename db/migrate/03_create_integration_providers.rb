# db/migrate/create_integration_providers.rb
class CreateIntegrationProviders < ActiveRecord::Migration[7.0]
  def change
    create_table :integration_providers do |t|
      t.references :integration_category, null: false, foreign_key: true, index: true

      t.string :name, null: false, limit: 100
      t.string :slug, null: false, limit: 50
      t.string :api_base_url, limit: 500
      t.text :description
      t.string :logo_url, limit: 500
      t.string :website_url, limit: 500
      t.string :status, limit: 20, default: 'active', null: false
      t.boolean :is_premium, default: false, null: false
      t.integer :display_order, default: 999, null: false
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end

    add_index :integration_providers, :slug, unique: true
    add_index :integration_providers, :status
    add_index :integration_providers, :is_active
    add_index :integration_providers, :is_premium
    add_index :integration_providers, :display_order
  end
end
