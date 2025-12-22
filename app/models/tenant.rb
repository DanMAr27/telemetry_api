# app/models/tenant.rb
class Tenant < ApplicationRecord
  has_many :tenant_integration_configurations, dependent: :destroy
  has_many :integration_providers, through: :tenant_integration_configurations
  has_many :vehicles, dependent: :destroy
  has_many :vehicle_refuelings, through: :vehicles
  has_many :vehicle_electric_charges, through: :vehicles

  validates :name, presence: true, length: { maximum: 255 }
  validates :slug, presence: true,
                   length: { maximum: 100 },
                   uniqueness: true,
                   format: { with: /\A[a-z0-9\-_]+\z/, message: "solo permite minúsculas, números, guiones y guiones bajos" }
  validates :status, presence: true,
                     inclusion: { in: %w[active suspended trial] }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :active, -> { where(status: "active") }
  scope :suspended, -> { where(status: "suspended") }
  scope :trial, -> { where(status: "trial") }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_name, -> { order(:name) }
  scope :with_integrations, -> { joins(:tenant_integration_configurations).distinct }
  scope :without_activity, ->(days = 30) {
    left_joins(:tenant_integration_configurations)
      .where("tenant_integration_configurations.last_sync_at < ? OR tenant_integration_configurations.last_sync_at IS NULL",
             days.days.ago)
      .distinct
  }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  before_validation :normalize_email

  def active?
    status == "active"
  end

  def suspended?
    status == "suspended"
  end

  def trial?
    status == "trial"
  end

  def active_integrations
    tenant_integration_configurations.active
  end

  def has_integration?(provider_slug)
    integration_providers.exists?(slug: provider_slug)
  end

  def integration_for(provider_slug)
    tenant_integration_configurations
      .joins(:integration_provider)
      .find_by(integration_providers: { slug: provider_slug })
  end

  def active_vehicles
    vehicles.active
  end

  def vehicles_with_telemetry
    vehicles.joins(:vehicle_provider_mappings)
            .where(vehicle_provider_mappings: { is_active: true })
            .distinct
  end

  # Verificación de datos asociados
  def has_associated_data?
    vehicles.any? ||
    tenant_integration_configurations.any? ||
    vehicle_refuelings.any? ||
    vehicle_electric_charges.any?
  end

  def associated_data_summary
    {
      vehicles: vehicles.count,
      integrations: tenant_integration_configurations.count,
      refuelings: VehicleRefueling.by_tenant(id).count,
      charges: VehicleElectricCharge.by_tenant(id).count,
      total_records: vehicles.count +
                    tenant_integration_configurations.count +
                    VehicleRefueling.by_tenant(id).count +
                    VehicleElectricCharge.by_tenant(id).count
    }
  end

  def last_activity_date
    [
      tenant_integration_configurations.maximum(:last_sync_at),
      vehicles.maximum(:updated_at),
      VehicleRefueling.by_tenant(id).maximum(:refueling_date),
      VehicleElectricCharge.by_tenant(id).maximum(:charge_start_time)
    ].compact.max
  end

  def days_since_last_activity
    return nil unless last_activity_date
    ((Time.current - last_activity_date) / 1.day).to_i
  end

  def inactive_days?(threshold = 30)
    days = days_since_last_activity
    days.present? && days > threshold
  end

  def statistics(from_date = nil, to_date = nil)
    from_date ||= 30.days.ago
    to_date ||= Time.current

    {
      vehicles: {
        total: vehicles.count,
        active: vehicles.active.count,
        with_telemetry: vehicles_with_telemetry.count
      },
      integrations: {
        total: tenant_integration_configurations.count,
        active: active_integrations.count,
        with_errors: tenant_integration_configurations.with_errors.count
      },
      refuelings: {
        total: VehicleRefueling.by_tenant(id)
          .between_dates(from_date, to_date).count,
        total_liters: VehicleRefueling.by_tenant(id)
          .between_dates(from_date, to_date)
          .sum(:volume_liters).to_f.round(2),
        total_cost: VehicleRefueling.by_tenant(id)
          .between_dates(from_date, to_date)
          .sum(:cost).to_f.round(2)
      },
      charges: {
        total: VehicleElectricCharge.by_tenant(id)
          .between_dates(from_date, to_date).count,
        total_kwh: VehicleElectricCharge.by_tenant(id)
          .between_dates(from_date, to_date)
          .sum(:energy_consumed_kwh).to_f.round(2)
      }
    }
  end

  # Operaciones de estado
  def activate!
    update!(status: "active")
  end

  def suspend!
    transaction do
      update!(status: "suspended")
      # Desactivar todas las integraciones
      tenant_integration_configurations.active.update_all(is_active: false)
    end
  end

  def move_to_trial!
    update!(status: "trial")
  end

  # Descripción
  def display_name
    "#{name} (#{status.humanize})"
  end

  private

  def generate_slug
    base_slug = name.parameterize
    self.slug = base_slug
    counter = 1

    while Tenant.exists?(slug: self.slug)
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end

  def normalize_email
    self.email = email&.strip&.downcase
  end
end
