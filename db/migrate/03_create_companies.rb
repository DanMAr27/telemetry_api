class CreateCompanies < ActiveRecord::Migration[7.0]
  def change
    # Si ya tienes tabla companies, skip esta migración
    return if table_exists?(:companies)

    create_table :companies do |t|
      t.string :name, null: false
      t.string :tax_id
      t.string :email
      t.string :phone
      t.text :address
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :companies, :tax_id, unique: true
    add_index :companies, :is_active
  end
end
