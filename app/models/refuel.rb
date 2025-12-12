# app/models/refuel.rb
class Refuel < ApplicationRecord
  # Associations
  belongs_to :vehicle

  # Validations
  validates :external_id, presence: true
  validates :provider_name, presence: true
  validates :refuel_date, presence: true
  validates :external_id, uniqueness: { scope: [ :vehicle_id, :provider_name ] }
  validates :volume_liters, numericality: { greater_than: 0 }, allow_nil: true
  validates :cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :recent, -> { order(refuel_date: :desc) }
  scope :by_provider, ->(provider) { where(provider_name: provider) }
  scope :in_date_range, ->(from, to) { where(refuel_date: from..to) }
  scope :for_vehicle, ->(vehicle_id) { where(vehicle_id: vehicle_id) }
  scope :with_location, -> { where.not(location_lat: nil, location_lng: nil) }

  # Instance methods
  def has_location?
    location_lat.present? && location_lng.present?
  end

  def coordinates
    return nil unless has_location?
    [ location_lat, location_lng ]
  end

  def consumption_per_100km
    return nil if volume_liters.nil? || distance_since_last_refuel_km.nil?
    return nil if distance_since_last_refuel_km.zero?

    (volume_liters / distance_since_last_refuel_km) * 100
  end

  # Detectores de anomalías básicos
  def exceeds_tank_capacity?
    return false if volume_liters.nil? || tank_capacity_liters.nil?
    volume_liters > tank_capacity_liters * 1.1 # 10% de margen
  end

  def suspicious_location?
    # TODO: Implementar lógica de zonas autorizadas
    false
  end
end
