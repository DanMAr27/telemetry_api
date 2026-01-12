class AddProductCatalogToFinancialTransactions < ActiveRecord::Migration[8.0]
  def change
    add_reference :financial_transactions, :product_catalog, foreign_key: true, index: true
    remove_column :financial_transactions, :product_code, :string
    remove_column :financial_transactions, :product_name, :string
  end
end
