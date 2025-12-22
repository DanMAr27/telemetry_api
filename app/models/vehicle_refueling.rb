# app/models/vehicle_refueling.rb
class VehicleRefueling < ApplicationRecord
  belongs_to :tenant
  belongs_to :vehicle
  belongs_to :integration_raw_data,
             class_name: "IntegrationRawData",
             optional: true

  has_one :raw_data_source,
          as: :normalized_record,
          class_name: "IntegrationRawData"

  validates :refueling_date, presence: true
  validates :volume_liters, presence: true,
                            numericality: { greater_than: 0 }
  validates :cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :currency, length: { is: 3 }, allow_blank: true
  validates :location_lat, numericality: {
    greater_than_or_equal_to: -90,
    less_than_or_equal_to: 90
  }, allow_nil: true
  validates :location_lng, numericality: {
    greater_than_or_equal_to: -180,
    less_than_or_equal_to: 180
  }, allow_nil: true
  validates :odometer_km, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :integration_raw_data_id, uniqueness: true, allow_nil: true

  scope :by_tenant, ->(tenant_id) { where(tenant_id: tenant_id) }
  scope :by_vehicle, ->(vehicle_id) { where(vehicle_id: vehicle_id) }
  scope :between_dates, ->(from, to) { where(refueling_date: from..to) }
  scope :recent, -> { order(refueling_date: :desc) }
  scope :estimated, -> { where(is_estimated: true) }
  scope :measured, -> { where(is_estimated: false) }
  scope :with_cost, -> { where.not(cost: nil) }
  scope :by_fuel_type, ->(type) { where(fuel_type: type) }
  scope :this_month, -> { where("refueling_date >= ?", Time.current.beginning_of_month) }
  scope :this_year, -> { where("refueling_date >= ?", Time.current.beginning_of_year) }

  def cost_per_liter
    return nil unless cost && volume_liters && volume_liters > 0
    (cost / volume_liters).round(2)
  end

  def has_location?
    location_lat.present? && location_lng.present?
  end

  def has_cost?
    cost.present? && cost > 0
  end

  def from_integration?
    integration_raw_data_id.present?
  end

  def manual?
    !from_integration?
  end

   def coordinates
    return nil unless has_location?
    [ location_lat, location_lng ]
  end

  def description
    "#{volume_liters}L el #{refueling_date.strftime('%d/%m/%Y')}"
  end

  def self.total_volume
    sum(:volume_liters).round(2)
  end

  def self.total_cost
    sum(:cost).round(2)
  end

  def self.average_volume
    average(:volume_liters).to_f.round(2)
  end

  def self.count_by_fuel_type
    group(:fuel_type).count
  end

  def self.monthly_summary(year = Time.current.year)
    where("EXTRACT(YEAR FROM refueling_date) = ?", year)
      .group("EXTRACT(MONTH FROM refueling_date)")
      .select(
        "EXTRACT(MONTH FROM refueling_date) as month",
        "COUNT(*) as count",
        "SUM(volume_liters) as total_liters",
        "SUM(cost) as total_cost"
      )
  end
end
