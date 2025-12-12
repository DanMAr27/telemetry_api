class CreateTelemetryProviders < ActiveRecord::Migration[7.0]
  def change
    create_table :telemetry_providers do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :api_base_url
      t.boolean :is_active, default: true
      t.jsonb :configuration_schema, default: {}
      t.text :description

      t.timestamps
    end

    add_index :telemetry_providers, :slug, unique: true
    add_index :telemetry_providers, :is_active
  end
end
