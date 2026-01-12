# app/models/vehicle_electric_charge.rb
class VehicleElectricCharge < ApplicationRecord
  belongs_to :tenant
  belongs_to :vehicle
  belongs_to :integration_raw_data,
             class_name: "IntegrationRawData",
             optional: true
  belongs_to :financial_transaction, optional: true

  has_one :raw_data_source,
          as: :normalized_record,
          class_name: "IntegrationRawData"

  # Enum para origen del dato
  # telemetry: Dato técnico de telemetría (Geotab, Samsara)
  # financial: Dato financiero de tarjeta (Solred, Cepsa) sin telemetría
  # manual: Ingreso manual del usuario
  # merged: Conciliación exitosa (telemetría + finanzas)
  enum :source, { telemetry: 0, financial: 1, manual: 2, merged: 3 }

  validates :charge_start_time, presence: true
  validates :charge_type, inclusion: { in: %w[AC DC], allow_blank: true }
  validates :source, presence: true
  validates :start_soc_percent, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 100
  }, allow_nil: true
  validates :end_soc_percent, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 100
  }, allow_nil: true
  validates :energy_consumed_kwh, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :peak_power_kw, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :duration_minutes, numericality: { greater_than: 0 }, allow_nil: true
  validates :location_lat, numericality: {
    greater_than_or_equal_to: -90,
    less_than_or_equal_to: 90
  }, allow_nil: true
  validates :location_lng, numericality: {
    greater_than_or_equal_to: -180,
    less_than_or_equal_to: 180
  }, allow_nil: true
  validates :integration_raw_data_id, uniqueness: true, allow_nil: true

  scope :by_tenant, ->(tenant_id) { where(tenant_id: tenant_id) }
  scope :by_vehicle, ->(vehicle_id) { where(vehicle_id: vehicle_id) }
  scope :between_dates, ->(from, to) { where(charge_start_time: from..to) }
  scope :recent, -> { order(charge_start_time: :desc) }
  scope :ac_charges, -> { where(charge_type: "AC") }
  scope :dc_charges, -> { where(charge_type: "DC") }
  scope :estimated, -> { where(is_estimated: true) }
  scope :measured, -> { where(is_estimated: false) }
  scope :complete_charges, -> { where("end_soc_percent >= ?", 95) }
  scope :this_month, -> { where("charge_start_time >= ?", Time.current.beginning_of_month) }
  scope :this_year, -> { where("charge_start_time >= ?", Time.current.beginning_of_year) }
  scope :from_telemetry, -> { where(source: :telemetry) }
  scope :from_financial, -> { where(source: :financial) }
  scope :from_manual, -> { where(source: :manual) }
  scope :reconciled, -> { where(source: :merged, is_reconciled: true) }
  scope :unreconciled, -> { where(source: [ :telemetry, :financial ], is_reconciled: false) }
  scope :pending_reconciliation, -> { where(is_reconciled: false) }

  def soc_gained
    return nil unless start_soc_percent && end_soc_percent
    (end_soc_percent - start_soc_percent).round(2)
  end

  def duration_hours
    return nil unless duration_minutes
    (duration_minutes / 60.0).round(2)
  end

  def average_power_kw
    return nil unless energy_consumed_kwh && duration_hours && duration_hours > 0
    (energy_consumed_kwh / duration_hours).round(2)
  end

  def has_location?
    location_lat.present? && location_lng.present?
  end

  def from_integration?
    integration_raw_data_id.present?
  end

  def manual?
    !from_integration?
  end

  def is_fast_charge?
    charge_type == "DC"
  end

  def is_slow_charge?
    charge_type == "AC"
  end

  def is_complete_charge?
    end_soc_percent && end_soc_percent >= 95
  end

  def coordinates
    return nil unless has_location?
    [ location_lat, location_lng ]
  end

  def description
    "#{energy_consumed_kwh}kWh (#{charge_type}) el #{charge_start_time.strftime('%d/%m/%Y')}"
  end

  def self.total_energy
    sum(:energy_consumed_kwh).to_f.round(2)
  end

  def self.average_energy
    average(:energy_consumed_kwh).to_f.round(2)
  end

  def self.total_duration_hours
    (sum(:duration_minutes).to_f / 60).round(2)
  end

  def self.count_by_charge_type
    group(:charge_type).count
  end

  def self.monthly_summary(year = Time.current.year)
    where("EXTRACT(YEAR FROM charge_start_time) = ?", year)
      .group("EXTRACT(MONTH FROM charge_start_time)")
      .select(
        "EXTRACT(MONTH FROM charge_start_time) as month",
        "COUNT(*) as count",
        "SUM(energy_consumed_kwh) as total_kwh",
        "AVG(duration_minutes) as avg_duration_minutes"
      )
  end
end
