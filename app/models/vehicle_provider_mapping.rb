# app/models/vehicle_provider_mapping.rb
class VehicleProviderMapping < ApplicationRecord
  belongs_to :vehicle
  belongs_to :tenant_integration_configuration

  # Delegaciones
  delegate :tenant, :integration_provider, to: :tenant_integration_configuration
  delegate :name, to: :vehicle, prefix: true
  delegate :license_plate, to: :vehicle, prefix: true

  validates :external_vehicle_id, presence: true, length: { maximum: 100 }

  # Un vehículo solo puede tener un mapeo activo por configuración
  validates :vehicle_id, uniqueness: {
    scope: [ :tenant_integration_configuration_id, :is_active ],
    conditions: -> { where(is_active: true) },
    message: "ya tiene un mapeo activo para esta configuración"
  }, if: :is_active?
  # Un external_vehicle_id solo puede estar mapeado una vez por configuración
  validates :external_vehicle_id, uniqueness: {
    scope: :tenant_integration_configuration_id,
    message: "ya está mapeado a otro vehículo en esta configuración"
  }

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

  before_create :set_mapped_at
  after_save :update_vehicle_telemetry_flag, if: :saved_change_to_is_active?

  def activate!
    # Desactivar otros mapeos del mismo vehículo para esta configuración
    self.class.where(
      vehicle_id: vehicle_id,
      tenant_integration_configuration_id: tenant_integration_configuration_id
    ).where.not(id: id).update_all(is_active: false)

    update!(is_active: true, mapped_at: Time.current)
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
  end

  def update_vehicle_telemetry_flag
    # Actualizar el flag has_telemetry del vehículo
    # (Este flag se puede agregar al modelo Vehicle si se necesita)
  end
end
