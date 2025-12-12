# app/models/vehicle_telemetry_config.rb
class VehicleTelemetryConfig < ApplicationRecord
  # Associations
  belongs_to :vehicle
  belongs_to :telemetry_credential
  has_one :telemetry_provider, through: :telemetry_credential
  has_one :company, through: :telemetry_credential

  # Validations
  validates :vehicle_id, uniqueness: { message: "can only have one telemetry configuration" }
  validates :external_device_id, presence: true
  validates :sync_frequency, inclusion: { in: %w[manual hourly daily weekly] }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :for_provider, ->(provider_slug) {
    joins(telemetry_credential: :telemetry_provider)
      .where(telemetry_providers: { slug: provider_slug })
  }
  scope :sync_refuels, -> { where("data_types @> ?", [ "refuels" ].to_json) }
  scope :sync_charges, -> { where("data_types @> ?", [ "charges" ].to_json) }

  # Instance methods
  def should_sync?(data_type)
    data_types.include?(data_type.to_s)
  end

  def provider_name
    telemetry_credential.provider_name
  end

  def credentials_hash
    telemetry_credential.credentials_hash
  end

  def sync_refuels?
    should_sync?("refuels")
  end

  def sync_charges?
    should_sync?("charges")
  end

  def sync_odometer?
    should_sync?("odometer")
  end
end
