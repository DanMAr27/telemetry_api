# app/models/vehicle_provider_mapping.rb
class VehicleProviderMapping < ApplicationRecord
  belongs_to :vehicle
  belongs_to :tenant_integration_configuration

  delegate :tenant, :integration_provider, to: :tenant_integration_configuration
  delegate :name, to: :vehicle, prefix: true
  delegate :license_plate, to: :vehicle, prefix: true

  validates :external_vehicle_id, presence: true, length: { maximum: 100 }
  validates :vehicle_id, uniqueness: {
    scope: [ :tenant_integration_configuration_id, :is_active ],
    conditions: -> { where(is_active: true) },
    message: "ya tiene un mapeo activo para esta configuración"
  }, if: :is_active?
  # Only enforce uniqueness of external_id within ACTIVE mappings.
  # Inactive mappings can share external_id (historical usage).
  validates :external_vehicle_id, uniqueness: {
    scope: :tenant_integration_configuration_id,
    conditions: -> { where(is_active: true) },
    message: "ya está mapeado a otro vehículo activo en esta configuración"
  }, if: :is_active?
  validates :valid_from, presence: true
  validate :validate_no_temporal_overlap
  validate :validate_dates_order

  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_config, ->(config_id) { where(tenant_integration_configuration_id: config_id) }
  scope :by_vehicle, ->(vehicle_id) { where(vehicle_id: vehicle_id) }
  scope :by_provider, ->(provider_slug) {
    joins(tenant_integration_configuration: :integration_provider)
      .where(integration_providers: { slug: provider_slug })
  }
  scope :by_external_id, ->(external_id) { where(external_vehicle_id: external_id) }
  scope :recent_sync, -> { order(last_sync_at: :desc) }

  before_validation :set_mapped_at

  def activate!(start_time: Time.current)
    VehicleProviderMapping.transaction do
      # 1. Deactivate ANY mapping that currently 'holds' this external_id for this config
      #    This handles the "Recycled ID" case: Provider moves "Device 123" from Vehicle A to Vehicle B.
      #    We must close Vehicle A's mapping.
      current_owner = VehicleProviderMapping.active
                                            .where(tenant_integration_configuration_id: tenant_integration_configuration_id)
                                            .where(external_vehicle_id: external_vehicle_id)
                                            .where.not(id: id) # Don't touch self if we are being reactivated (though likely we are new)

      current_owner.each do |mapping|
        mapping.update!(is_active: false, valid_until: start_time)
      end

      # 2. Deactivate any previous active mapping for THIS vehicle on THIS config
      #    This handles "Swapped Device": Vehicle A switches from "Device 123" to "Device 456".
      self.class.where(
        vehicle_id: vehicle_id,
        tenant_integration_configuration_id: tenant_integration_configuration_id
      ).where.not(id: id).where(is_active: true).each do |mapping|
        mapping.update!(is_active: false, valid_until: start_time)
      end

      # 3. Activate self
      update!(is_active: true, valid_from: start_time, valid_until: nil)
    end
  end

  # Resolves which vehicle was associated with an external_id at a specific point in time.
  # This is CRITICAL for reprocessing historical raw data.
  def self.resolve_vehicle(external_id:, config_id:, timestamp:)
    # 1. Try to find a mapping that was VALID during the timestamp
    mapping = where(tenant_integration_configuration_id: config_id, external_vehicle_id: external_id)
              .where("valid_from <= ?", timestamp)
              .where("valid_until IS NULL OR valid_until > ?", timestamp)
              .order(valid_from: :desc) # In case of overlaps (shouldn't happen with strict logic), take the latest validity start
              .first

    # 2. Return the vehicle if mapping found
    mapping&.vehicle
  end

  def deactivate!
    update!(is_active: false)
  end

  def provider_name
    integration_provider.name
  end

  def provider_slug
    integration_provider.slug
  end

  def update_last_sync!
    update!(last_sync_at: Time.current)
  end

  def description
    "#{vehicle_name} (#{vehicle_license_plate}) ↔ #{provider_name} [#{external_vehicle_id}]"
  end

  private

  def set_mapped_at
    self.mapped_at ||= Time.current
    self.valid_from ||= Time.current
  end

  def validate_no_temporal_overlap
    return unless valid_from.present?

    # Define our range end (infinity if active/nil)
    our_end = valid_until || Time.current + 100.years

    # Query for potential overlaps
    overlaps = VehicleProviderMapping
      .where(tenant_integration_configuration_id: tenant_integration_configuration_id)
      .where(external_vehicle_id: external_vehicle_id)
      .where.not(id: id) # Exclude self

    # Check for overlap: (StartA < EndB) and (EndA > StartB)
    # Using SQL for efficiency:
    # (other.valid_from < our_end) AND (other.valid_until IS NULL OR other.valid_until > our_start)
    overlaps = overlaps.where(
      "valid_from < ? AND (valid_until IS NULL OR valid_until > ?)",
      our_end,
      valid_from
    )

    if overlaps.exists?
      errors.add(:base, "Este dispositivo ya está asignado a otro vehículo en este rango de fechas")
    end
  end

  def validate_dates_order
    return unless valid_from && valid_until

    if valid_until < valid_from
      errors.add(:valid_until, "no puede ser anterior a la fecha de inicio (#{valid_from})")
    end
  end
end
