# app/models/vehicle.rb
class Vehicle < ApplicationRecord
  belongs_to :tenant

  has_many :vehicle_provider_mappings, dependent: :destroy
  has_many :tenant_integration_configurations, through: :vehicle_provider_mappings

  has_many :vehicle_refuelings, dependent: :destroy
  has_many :vehicle_electric_charges, dependent: :destroy
  has_many :vehicle_kms, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validates :license_plate, presence: true,
                            length: { maximum: 20 },
                            uniqueness: { scope: :tenant_id, case_sensitive: false }

  validates :vin, length: { is: 17 }, allow_blank: true,
                  uniqueness: true,
                  format: { with: /\A[A-HJ-NPR-Z0-9]{17}\z/, message: "formato VIN inválido" }
  validates :status, presence: true,
                     inclusion: { in: %w[active maintenance inactive sold] }
  validates :fuel_type, inclusion: {
    in: %w[diesel gasoline electric hybrid lpg cng hydrogen],
    message: "%{value} no es un tipo de combustible válido"
  }, allow_blank: true
  validates :vehicle_type, inclusion: {
    in: %w[car van truck motorcycle bus],
    message: "%{value} no es un tipo de vehículo válido"
  }, allow_blank: true
  validates :year, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1900,
    less_than_or_equal_to: -> { Date.current.year + 1 }
  }, allow_nil: true
  validates :tank_capacity_liters, numericality: { greater_than: 0 }, allow_nil: true
  validates :battery_capacity_kwh, numericality: { greater_than: 0 }, allow_nil: true
  validates :initial_odometer_km, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :current_odometer_km, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :active, -> { where(status: "active") }
  scope :inactive, -> { where(status: "inactive") }
  scope :in_maintenance, -> { where(status: "maintenance") }
  scope :electric, -> { where(is_electric: true) }
  scope :combustion, -> { where(is_electric: false) }
  scope :by_fuel_type, ->(type) { where(fuel_type: type) }
  scope :by_vehicle_type, ->(type) { where(vehicle_type: type) }
  scope :by_brand, ->(brand) { where(brand: brand) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_name, -> { order(:name) }

  before_validation :normalize_license_plate
  before_validation :set_is_electric_flag
  before_save :normalize_vin

  def active?
    status == "active"
  end

  def in_maintenance?
    status == "maintenance"
  end

  def inactive?
    status == "inactive"
  end

  def sold?
    status == "sold"
  end

   def electric?
    is_electric
  end

  def combustion?
    !is_electric
  end

  def hybrid?
    fuel_type == "hybrid"
  end

  def has_telemetry?
    vehicle_provider_mappings.active.any?
  end

  def active_telemetry_provider
    vehicle_provider_mappings.active.first&.integration_provider
  end

  def needs_maintenance?
    return false unless next_maintenance_date
    next_maintenance_date <= Date.current
  end

  def days_until_maintenance
    return nil unless next_maintenance_date
    (next_maintenance_date - Date.current).to_i
  end

  def total_km_driven
    return 0 unless initial_odometer_km && current_odometer_km
    current_odometer_km - initial_odometer_km
  end

  def update_odometer!(new_odometer)
    update!(current_odometer_km: new_odometer) if new_odometer > (current_odometer_km || 0)
  end

  def full_name
    parts = [ brand, model, license_plate ].compact
    parts.join(" - ")
  end

  def display_name
    "#{name} (#{license_plate})"
  end

  def self.fuel_types
    %w[diesel gasoline electric hybrid lpg cng hydrogen]
  end

  def self.vehicle_types
    %w[car van truck motorcycle bus]
  end

  def self.statuses
    %w[active maintenance inactive sold]
  end

  private

  def normalize_license_plate
    self.license_plate = license_plate&.upcase&.strip
  end

  def set_is_electric_flag
    self.is_electric = (fuel_type == "electric")
  end

  def normalize_vin
    self.vin = vin&.upcase&.strip if vin.present?
  end
end
