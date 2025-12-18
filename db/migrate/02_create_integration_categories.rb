# db/migrate/create_integration_categories.rb
class CreateIntegrationCategories < ActiveRecord::Migration[7.0]
  def change
    create_table :integration_categories do |t|
      t.string :name, null: false, limit: 100
      t.string :slug, null: false, limit: 50
      t.text :description
      t.string :icon, limit: 50
      t.integer :display_order, default: 999, null: false
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end

    add_index :integration_categories, :slug, unique: true
    add_index :integration_categories, :is_active
    add_index :integration_categories, :display_order
  end
end
