# app/services/financial/product_classification_service.rb
module Financial
  class ProductClassificationService
    def self.classify(financial_transaction)
      provider = financial_transaction.tenant_integration_configuration.integration_provider

      # Buscar en catálogo por código y nombre
      product = ProductCatalog.find_by_code_or_name(
        provider.id,
        code: financial_transaction.product_code,
        name: financial_transaction.product_name
      )

      return product.energy_type if product

      # Fallback: inferir por nombre del producto
      infer_from_name(financial_transaction.product_name)
    end

    private

    def self.infer_from_name(product_name)
      return "other" if product_name.blank?

      name_lower = product_name.downcase

      # Palabras clave para combustibles
      fuel_keywords = %w[
        gasolina diesel gasóleo fuel diésel gas glp gnc lpg cng
        efitec casco premium autogas gasoil efi
      ]
      return "fuel" if fuel_keywords.any? { |kw| name_lower.include?(kw) }

      # Palabras clave para electricidad
      electric_keywords = %w[eléctric electric recarga charge kwh]
      return "electric" if electric_keywords.any? { |kw| name_lower.include?(kw) }

      # Por defecto: otros servicios
      "other"
    end
  end
end
