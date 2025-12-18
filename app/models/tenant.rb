# app/models/tenant.rb
class Tenant < ApplicationRecord
  has_many :tenant_integration_configurations, dependent: :destroy
  has_many :integration_providers, through: :tenant_integration_configurations
  has_many :vehicles, dependent: :destroy

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

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

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

  # Método auxiliar para obtener vehículos activos
  def active_vehicles
    vehicles.active
  end

  # Método para obtener vehículos con telemetría
  def vehicles_with_telemetry
    vehicles.joins(:vehicle_provider_mappings)
            .where(vehicle_provider_mappings: { is_active: true })
            .distinct
  end

  private

  def generate_slug
    self.slug = name.parameterize
  end
end
