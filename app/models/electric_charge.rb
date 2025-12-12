# app/models/electric_charge.rb
class ElectricCharge < ApplicationRecord
  # Associations
  belongs_to :vehicle

  # Validations
  validates :external_id, presence: true
  validates :provider_name, presence: true
  validates :start_time, presence: true
  validates :external_id, uniqueness: { scope: [ :vehicle_id, :provider_name ] }
  validates :energy_consumed_kwh, numericality: { greater_than: 0 }, allow_nil: true
  validates :start_soc_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :end_soc_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :charge_type, inclusion: { in: %w[AC DC], allow_nil: true }

  # Scopes
  scope :recent, -> { order(start_time: :desc) }
  scope :by_provider, ->(provider) { where(provider_name: provider) }
  scope :in_date_range, ->(from, to) { where(start_time: from..to) }
  scope :for_vehicle, ->(vehicle_id) { where(vehicle_id: vehicle_id) }
  scope :ac_charges, -> { where(charge_type: "AC") }
  scope :dc_charges, -> { where(charge_type: "DC") }
  scope :with_location, -> { where.not(location_lat: nil, location_lng: nil) }

  # Instance methods
  def has_location?
    location_lat.present? && location_lng.present?
  end

  def coordinates
    return nil unless has_location?
    [ location_lat, location_lng ]
  end

  def soc_gained_percent
    return nil if start_soc_percent.nil? || end_soc_percent.nil?
    end_soc_percent - start_soc_percent
  end

  def charging_efficiency_percent
    return nil if measured_charger_energy_in_kwh.nil? || measured_battery_energy_in_kwh.nil?
    return nil if measured_charger_energy_in_kwh.zero?

    (measured_battery_energy_in_kwh / measured_charger_energy_in_kwh) * 100
  end

  def duration_hours
    return nil if duration_minutes.nil?
    duration_minutes / 60.0
  end

  def average_power_kw
    return nil if energy_consumed_kwh.nil? || duration_hours.nil?
    return nil if duration_hours.zero?

    energy_consumed_kwh / duration_hours
  end

  # Detectores de anomalías
  def low_efficiency?
    return false if charging_efficiency_percent.nil?
    charging_efficiency_percent < 80 # Menos del 80% es sospechoso
  end

  def fast_charge?
    charge_type == "DC"
  end

  def slow_charge?
    charge_type == "AC"
  end
end
