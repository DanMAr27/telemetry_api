# app/models/integration_provider.rb
class IntegrationProvider < ApplicationRecord
  belongs_to :integration_category
  has_one :integration_auth_schema, dependent: :destroy
  has_many :integration_features, dependent: :destroy
  has_many :tenant_integration_configurations, dependent: :restrict_with_error

  # Enum para tipo de conexión
  # api: Integraciones con API REST (Geotab, Samsara, etc.)
  # file_upload: Carga manual de archivos (Solred Excel)
  # sftp: Descarga automática vía SFTP
  # email: Recepción por correo electrónico
  enum :connection_type, { api: 0, file_upload: 1, sftp: 2, email: 3 }

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true,
                   length: { maximum: 50 },
                   uniqueness: true,
                   format: { with: /\A[a-z0-9_]+\z/, message: "solo permite minúsculas, números y guiones bajos" }
  validates :status, presence: true,
                     inclusion: { in: %w[active coming_soon deprecated beta] }
  validates :connection_type, presence: true
  validates :api_base_url, length: { maximum: 500 }, allow_blank: true
  validates :logo_url, length: { maximum: 500 }, allow_blank: true
  validates :website_url, length: { maximum: 500 }, allow_blank: true
  validates :display_order, presence: true, numericality: { only_integer: true }

  scope :active, -> { where(is_active: true) }
  scope :by_status, ->(status) { where(status: status) }
  scope :premium, -> { where(is_premium: true) }
  scope :free, -> { where(is_premium: false) }
  scope :ordered, -> { order(display_order: :asc, name: :asc) }
  scope :for_marketplace, -> { active.where(status: [ "active", "beta" ]).ordered }

  # Scopes por tipo de conexión
  scope :api_based, -> { where(connection_type: :api) }
  scope :file_based, -> { where(connection_type: [ :file_upload, :sftp, :email ]) }
  scope :requires_upload, -> { where(connection_type: :file_upload) }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  def available?
    is_active && status.in?([ "active", "beta" ])
  end

  def ready_for_production?
    is_active && status == "active"
  end

  def configured_by_tenant?(tenant)
    tenant_integration_configurations.exists?(tenant: tenant)
  end

  def active_configurations_count
    tenant_integration_configurations.active.count
  end

  # Métodos de ayuda para tipo de conexión
  def requires_api_credentials?
    api?
  end

  def supports_file_upload?
    file_upload? || sftp? || email?
  end

  def requires_manual_upload?
    file_upload?
  end

  def requires_scheduling?
    api? || sftp?
  end

  def requires_authentication?
    return false if file_upload?
    return false if integration_auth_schema.nil?
    true
  end

  private

  def generate_slug
    self.slug = name.parameterize.underscore
  end
end
