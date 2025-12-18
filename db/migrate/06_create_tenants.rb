# db/migrate/create_tenants.rb
class CreateTenants < ActiveRecord::Migration[7.0]
  def change
    create_table :tenants do |t|
      t.string :name, null: false, limit: 255
      t.string :slug, null: false, limit: 100
      t.string :email, limit: 255
      t.string :status, null: false, limit: 20, default: 'active'
      t.jsonb :settings, null: false, default: {}

      t.timestamps
    end

    add_index :tenants, :slug, unique: true
    add_index :tenants, :status
    add_index :tenants, :created_at
  end
end
