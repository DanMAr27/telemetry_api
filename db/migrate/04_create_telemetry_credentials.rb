class CreateTelemetryCredentials < ActiveRecord::Migration[7.0]
  def change
    create_table :telemetry_credentials do |t|
      t.references :company, null: false, foreign_key: true
      t.references :telemetry_provider, null: false, foreign_key: true

      t.text :encrypted_credentials
      t.string :encrypted_credentials_iv

      t.boolean :is_active, default: true
      t.datetime :last_sync_at
      t.datetime :last_successful_sync_at

      t.timestamps
    end

    add_index :telemetry_credentials, [ :company_id, :telemetry_provider_id ],
              unique: true,
              name: 'idx_credentials_company_provider'
    add_index :telemetry_credentials, :is_active
    add_index :telemetry_credentials, :last_sync_at
  end
end
