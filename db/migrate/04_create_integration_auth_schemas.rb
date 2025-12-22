# db/migrate/create_integration_auth_schemas.rb
class CreateIntegrationAuthSchemas < ActiveRecord::Migration[7.0]
  def change
    create_table :integration_auth_schemas do |t|
      t.references :integration_provider, null: false, foreign_key: true

      t.jsonb :auth_fields, null: false, default: {}
      t.jsonb :example_credentials, default: {}
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end
    add_index :integration_auth_schemas, :integration_provider_id,
              unique: true,
              where: "is_active = true",
              name: 'idx_auth_schemas_active_provider'

    add_index :integration_auth_schemas, :is_active
  end
end
