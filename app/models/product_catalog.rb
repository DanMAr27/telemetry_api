# app/models/product_catalog.rb
class ProductCatalog < ApplicationRecord
  belongs_to :integration_provider

  # Enum para tipo de energía
  enum :energy_type, {
    fuel: "fuel",           # Combustibles
    electric: "electric",   # Electricidad
    other: "other"          # Otros (peajes, lavados, etc.)
  }, prefix: :energy

  # Enum para tipo de combustible (solo si energy_type == 'fuel')
  enum :fuel_type, {
    gasoline: "gasoline",   # Gasolina
    diesel: "diesel",       # Diésel
    lpg: "lpg",            # Gas Licuado de Petróleo
    cng: "cng",            # Gas Natural Comprimido
    premium: "premium",     # Premium/Super
    bio: "bio"             # Biodiésel/Bioetanol
  }, prefix: :fuel, default: nil

  validates :product_code, presence: true
  validates :product_name, presence: true
  validates :energy_type, presence: true
  validates :product_code, uniqueness: {
    scope: [ :integration_provider_id, :product_name ],
    message: "and product_name combination already exists for this provider"
  }

  scope :active, -> { where(is_active: true) }
  scope :by_provider, ->(provider_id) { where(integration_provider_id: provider_id) }
  scope :fuels, -> { where(energy_type: "fuel") }
  scope :electric, -> { where(energy_type: "electric") }
  scope :others, -> { where(energy_type: "other") }

  # Buscar producto por código o nombre
  def self.find_by_code_or_name(provider_id, code: nil, name: nil)
    scope = by_provider(provider_id).active

    # Prioridad 1: Buscar por código exacto (es el identificador más fiable)
    if code.present?
      product = scope.find_by(product_code: code)
      return product if product
    end

    # Prioridad 2: Buscar por nombre (si no se encontró por código o no hay código)
    if name.present?
      scope.find_by("LOWER(product_name) = ?", name.downcase)
    end
  end
end
