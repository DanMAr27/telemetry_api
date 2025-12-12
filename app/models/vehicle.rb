# app/models/vehicle.rb
class Vehicle < ApplicationRecord
  # Associations
  belongs_to :company
  has_one :vehicle_telemetry_config, dependent: :destroy
  has_many :refuels, dependent: :destroy
  has_many :electric_charges, dependent: :destroy
  has_many :telemetry_sync_logs, dependent: :nullify

  # Validations
  validates :name, presence: true
  validates :license_plate, presence: true, uniqueness: { scope: :company_id }
  validates :fuel_type, inclusion: { in: %w[combustion electric hybrid], allow_nil: true }
  validates :tank_capacity_liters, numericality: { greater_than: 0 }, allow_nil: true
  validates :battery_capacity_kwh, numericality: { greater_than: 0 }, allow_nil: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :with_telemetry, -> { joins(:vehicle_telemetry_config).where(vehicle_telemetry_configs: { is_active: true }) }
  scope :without_telemetry, -> { where.missing(:vehicle_telemetry_config) }
  scope :combustion, -> { where(fuel_type: "combustion") }
  scope :electric, -> { where(fuel_type: "electric") }
  scope :hybrid, -> { where(fuel_type: "hybrid") }

  # Instance methods
  def has_telemetry?
    vehicle_telemetry_config.present? && vehicle_telemetry_config.is_active?
  end

  def requires_manual_entry?
    !has_telemetry?
  end

  def telemetry_provider_name
    vehicle_telemetry_config&.provider_name
  end

  def is_electric?
    fuel_type == "electric"
  end

  def is_combustion?
    fuel_type == "combustion"
  end

  def is_hybrid?
    fuel_type == "hybrid"
  end

  def last_refuel
    refuels.recent.first
  end

  def last_charge
    electric_charges.recent.first
  end

  def total_refuels_count
    refuels.count
  end

  def total_charges_count
    electric_charges.count
  end

  def display_name
    "#{name} (#{license_plate})"
  end
end
