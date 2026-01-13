# app/models/tenant_integration_configuration.rb
class TenantIntegrationConfiguration < ApplicationRecord
  encrypts :credentials, deterministic: false

  belongs_to :tenant
  belongs_to :integration_provider
  has_many :vehicle_provider_mappings, dependent: :destroy
  has_many :vehicles, through: :vehicle_provider_mappings
  has_many :integration_sync_executions, dependent: :destroy
  has_many :integration_raw_data, class_name: "IntegrationRawData", dependent: :destroy

  delegate :name, :slug, :logo_url, :api_base_url, to: :integration_provider, prefix: true
  delegate :integration_features, :integration_auth_schema, to: :integration_provider

  validates :tenant_id, uniqueness: {
    scope: :integration_provider_id,
    message: "ya tiene una configuración para este proveedor"
  }
  validates :enabled_features, presence: true
  validate :validate_enabled_features_structure
  validate :validate_credentials_structure, if: -> { credentials.present? }
  validates :sync_frequency, presence: true, inclusion: { in: %w[daily weekly monthly] }, if: -> { integration_provider&.requires_scheduling? }
  validates :sync_hour, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 23
  }, if: -> { integration_provider&.requires_scheduling? }

  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_provider, ->(provider_slug) {
    joins(:integration_provider).where(integration_providers: { slug: provider_slug })
  }
  scope :with_errors, -> { where(last_sync_status: "error") }
  scope :successful, -> { where(last_sync_status: "success") }

  before_save :set_activated_at, if: -> { is_active_changed? && is_active? }

  def activate!
    return false unless can_be_activated?
    update!(is_active: true)
  end

  def deactivate!
    update!(is_active: false)
  end

  def active?
    is_active
  end

  def can_be_activated?
    # Verificaciones para poder activar
    if integration_provider&.requires_authentication?
      return false unless credentials.present?
    end
    return false unless enabled_features.any?
    true
  end

  def has_error?
    last_sync_status == "error"
  end

  def last_sync_successful?
    last_sync_status == "success"
  end

  def feature_enabled?(feature_key)
    enabled_features.include?(feature_key.to_s)
  end

  def available_features
    integration_provider.integration_features.active.where(feature_key: enabled_features)
  end

  # Descripción de programación para mostrar en UI
  def sync_schedule_description
    case sync_frequency
    when "daily"
      "Todos los días a las #{format_hour(sync_hour)}"
    when "weekly"
      day_name = %w[Domingo Lunes Martes Miércoles Jueves Viernes Sábado][sync_day_of_week || 0]
      "Todos los #{day_name} a las #{format_hour(sync_hour)}"
    when "monthly"
      day_desc = sync_day_of_month == "start" ? "el primer día del mes" : "el último día del mes"
      "#{day_desc.capitalize} a las #{format_hour(sync_hour)}"
    end
  end

  # Marcar última sync como exitosa
  def mark_sync_success!(timestamp = Time.current)
    update!(
      last_sync_at: timestamp,
      last_sync_status: "success",
      last_sync_error: nil
    )
  end

  # Marcar última sync con error
  def mark_sync_error!(error_message)
    update!(
      last_sync_at: Time.current,
      last_sync_status: "error",
      last_sync_error: error_message
    )
  end

  # Vehículos mapeados activos
  def mapped_vehicles
    vehicles.joins(:vehicle_provider_mappings)
            .where(vehicle_provider_mappings: { is_active: true })
            .distinct
  end

  # Verificar si un vehículo está mapeado
  def vehicle_mapped?(vehicle)
    vehicle_provider_mappings.active.exists?(vehicle: vehicle)
  end

  # Obtener mapeo de un vehículo
  def mapping_for(vehicle)
    vehicle_provider_mappings.active.find_by(vehicle: vehicle)
  end

  # Última ejecución de sync
  def last_sync_execution
    integration_sync_executions.recent.first
  end

  # Ejecuciones por feature
  def sync_executions_for(feature_key)
    integration_sync_executions.by_feature(feature_key).recent
  end

  # Estadísticas
  def sync_statistics
    {
      total_executions: integration_sync_executions.count,
      completed: integration_sync_executions.completed.count,
      failed: integration_sync_executions.failed.count,
      total_raw_records: integration_raw_data.count,
      pending_records: integration_raw_data.pending.count,
      failed_records: integration_raw_data.failed.count
    }
  end

  private

  def set_activated_at
    self.activated_at = Time.current
  end

  def format_hour(hour)
    Time.current.change(hour: hour).strftime("%H:%M")
  end

  def validate_credentials_structure
    return unless integration_provider&.integration_auth_schema

    schema = integration_provider.integration_auth_schema
    required_fields = schema.required_fields.map { |f| f["name"] }

    # Obtener el valor de credentials
    creds = credentials

    # Si credentials es nil, salir
    return if creds.nil?

    # Verificar que sea un Hash
    unless creds.is_a?(Hash)
      errors.add(:credentials, "debe ser un objeto JSON válido (recibido: #{creds.class})")
      return
    end

    # Validar campos requeridos
    missing_fields = required_fields - creds.keys.map(&:to_s)

    if missing_fields.any?
      errors.add(:credentials, "faltan campos requeridos: #{missing_fields.join(', ')}")
    end
  end

  def validate_enabled_features_structure
    unless enabled_features.is_a?(Array)
      errors.add(:enabled_features, "debe ser un array")
      return
    end

    # Validar que las features existan y estén activas
    available_feature_keys = integration_provider.integration_features.active.pluck(:feature_key)
    invalid_features = enabled_features - available_feature_keys

    if invalid_features.any?
      errors.add(:enabled_features, "contiene features no disponibles: #{invalid_features.join(', ')}")
    end
  end
end
