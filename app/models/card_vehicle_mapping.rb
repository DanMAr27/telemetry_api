# app/models/card_vehicle_mapping.rb
class CardVehicleMapping < ApplicationRecord
  belongs_to :tenant
  belongs_to :vehicle
  belongs_to :integration_provider

  validates :card_number, presence: true
  validates :card_number, uniqueness: {
    scope: [ :tenant_id, :integration_provider_id ],
    message: "already mapped for this tenant and provider"
  }

  validate :vehicle_belongs_to_tenant

  before_validation :normalize_card_number

  scope :active, -> { where(is_active: true) }
  scope :by_tenant, ->(tenant_id) { where(tenant_id: tenant_id) }
  scope :by_provider, ->(provider_id) { where(integration_provider_id: provider_id) }
  scope :valid_now, -> {
    where("valid_from IS NULL OR valid_from <= ?", Time.current)
      .where("valid_until IS NULL OR valid_until >= ?", Time.current)
  }

  # Buscar mapeo por tarjeta
  def self.find_by_card(tenant_id, provider_id, card_number)
    normalized = normalize_card_number_value(card_number)

    by_tenant(tenant_id)
      .by_provider(provider_id)
      .active
      .valid_now
      .find_by(card_number: normalized)
  end

  # Normalizar número de tarjeta (quitar espacios, guiones)
  def self.normalize_card_number_value(card_number)
    return nil if card_number.blank?
    card_number.to_s.gsub(/[\s\-]/, "").upcase
  end

  private

  def normalize_card_number
    self.card_number = self.class.normalize_card_number_value(card_number)
  end

  def vehicle_belongs_to_tenant
    if vehicle && vehicle.tenant_id != tenant_id
      errors.add(:vehicle, "must belong to the same tenant")
    end
  end
end
