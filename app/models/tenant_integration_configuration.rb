# app/models/tenant_integration_configuration.rb
class TenantIntegrationConfiguration < ApplicationRecord
  # Encriptación de credenciales
  encrypts :credentials

  belongs_to :tenant
  belongs_to :integration_provider

  has_many :vehicle_provider_mappings, dependent: :destroy
  has_many :vehicles, through: :vehicle_provider_mappings
  has_many :integration_sync_executions, dependent: :destroy
  has_many :integration_raw_data,
           class_name: "IntegrationRawData",
           dependent: :destroy

  delegate :name, :slug, :logo_url, :api_base_url, to: :integration_provider, prefix: true
  delegate :integration_features, :integration_auth_schema, to: :integration_provider

  validates :tenant_id, uniqueness: {
    scope: :integration_provider_id,
    message: "ya tiene una configuración para este proveedor"
  }
  validates :sync_frequency, presence: true,
                             inclusion: { in: %w[daily weekly monthly] }
  validates :sync_hour, presence: true,
                        numericality: {
                          only_integer: true,
                          greater_than_or_equal_to: 0,
                          less_than_or_equal_to: 23
                        }
  validates :sync_day_of_week,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 6
            },
            if: -> { sync_frequency == "weekly" }
  validates :sync_day_of_week,
            absence: { message: "debe estar vacío para frecuencia diaria o mensual" },
            unless: -> { sync_frequency == "weekly" }
  validates :sync_day_of_month,
            inclusion: { in: %w[start end] },
            if: -> { sync_frequency == "monthly" }

  validates :sync_day_of_month,
            absence: { message: "debe estar vacío para frecuencia diaria o semanal" },
            unless: -> { sync_frequency == "monthly" }
  validate :validate_credentials_structure, if: -> { credentials.present? }
  validate :validate_enabled_features, if: -> { enabled_features.present? }

  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :by_provider, ->(provider_slug) {
    joins(:integration_provider).where(integration_providers: { slug: provider_slug })
  }
  scope :with_errors, -> { where(last_sync_status: "error") }
  scope :successful, -> { where(last_sync_status: "success") }
  scope :ready_for_sync, -> {
    active.where("last_sync_at IS NULL OR last_sync_at < ?", 1.hour.ago)
  }

  before_save :set_activated_at, if: -> { is_active_changed? && is_active? }

  def activate!
    update!(is_active: true)
  end

  def deactivate!
    update!(is_active: false)
  end

  def active?
    is_active
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

  def calculate_next_sync_at
    base_time = Time.current.change(hour: sync_hour, min: 0, sec: 0)

    case sync_frequency
    when "daily"
      base_time > Time.current ? base_time : base_time + 1.day

    when "weekly"
      days_until_target = (sync_day_of_week - base_time.wday) % 7
      days_until_target = 7 if days_until_target.zero? && base_time < Time.current
      base_time + days_until_target.days

    when "monthly"
      if sync_day_of_month == "start"
        target = base_time.beginning_of_month.change(hour: sync_hour)
        target > Time.current ? target : (target + 1.month).beginning_of_month.change(hour: sync_hour)
      else # 'end'
        target = base_time.end_of_month.beginning_of_day.change(hour: sync_hour)
        target > Time.current ? target : (base_time + 1.month).end_of_month.beginning_of_day.change(hour: sync_hour)
      end
    end
  end

  def sync_schedule_description
    case sync_frequency
    when "daily"
      "Todos los días a las #{format_hour(sync_hour)}"
    when "weekly"
      day_name = I18n.t("date.day_names")[sync_day_of_week]
      "Todos los #{day_name} a las #{format_hour(sync_hour)}"
    when "monthly"
      day_desc = sync_day_of_month == "start" ? "el primer día del mes" : "el último día del mes"
      "#{day_desc.capitalize} a las #{format_hour(sync_hour)}"
    end
  end

  def mark_sync_success!(timestamp = Time.current)
    update!(
      last_sync_at: timestamp,
      last_sync_status: "success",
      last_sync_error: nil
    )
  end

  def mark_sync_error!(error_message)
    update!(
      last_sync_at: Time.current,
      last_sync_status: "error",
      last_sync_error: error_message
    )
  end

  # Método auxiliar para obtener vehículos mapeados activos
  def mapped_vehicles
    vehicles.joins(:vehicle_provider_mappings)
            .where(vehicle_provider_mappings: { is_active: true })
            .distinct
  end

  # Método para verificar si un vehículo está mapeado
  def vehicle_mapped?(vehicle)
    vehicle_provider_mappings.active.exists?(vehicle: vehicle)
  end

  # Obtener mapeo de un vehículo
  def mapping_for(vehicle)
    vehicle_provider_mappings.active.find_by(vehicle: vehicle)
  end

  # Método auxiliar para obtener última ejecución
  def last_sync_execution
    integration_sync_executions.recent.first
  end

  # Método auxiliar para obtener ejecuciones por feature
  def sync_executions_for(feature_key)
    integration_sync_executions.by_feature(feature_key).recent
  end

  # Estadísticas de sincronización
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
    return unless integration_provider.integration_auth_schema

    schema = integration_provider.integration_auth_schema
    required_fields = schema.required_fields.map { |f| f["name"] }

    unless credentials.is_a?(Hash)
      errors.add(:credentials, "debe ser un objeto JSON válido")
      return
    end

    missing_fields = required_fields - credentials.keys.map(&:to_s)

    if missing_fields.any?
      errors.add(:credentials, "faltan campos requeridos: #{missing_fields.join(', ')}")
    end
  end

  def validate_enabled_features
    unless enabled_features.is_a?(Array)
      errors.add(:enabled_features, "debe ser un array")
      return
    end

    available_feature_keys = integration_provider.integration_features.active.pluck(:feature_key)
    invalid_features = enabled_features - available_feature_keys

    if invalid_features.any?
      errors.add(:enabled_features, "contiene features no disponibles: #{invalid_features.join(', ')}")
    end
  end
end
