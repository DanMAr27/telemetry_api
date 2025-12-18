# db/migrate/create_integration_features.rb
class CreateIntegrationFeatures < ActiveRecord::Migration[7.0]
  def change
    create_table :integration_features do |t|
      t.references :integration_provider, null: false, foreign_key: true, index: true

      t.string :feature_key, null: false, limit: 50
      t.string :feature_name, null: false, limit: 100
      t.text :feature_description
      t.integer :display_order, default: 999, null: false
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end

    add_index :integration_features, [ :integration_provider_id, :feature_key ],
              unique: true,
              name: 'idx_features_provider_key'

    add_index :integration_features, :feature_key
    add_index :integration_features, :is_active
    add_index :integration_features, :display_order
  end
end
