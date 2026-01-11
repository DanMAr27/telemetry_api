# app/models/integration_sync_execution.rb
class IntegrationSyncExecution < ApplicationRecord
  belongs_to :tenant_integration_configuration
  has_many :integration_raw_data,
           class_name: "IntegrationRawData",
           dependent: :destroy

  delegate :tenant, :integration_provider, to: :tenant_integration_configuration
  delegate :name, to: :integration_provider, prefix: true

  validates :feature_key, presence: true,
                          inclusion: {
                            in: %w[fuel battery trips real_time_location odometer diagnostics financial_import],
                            message: "%{value} no es una feature válida"
                          }
  validates :trigger_type, presence: true,
                           inclusion: { in: %w[manual scheduled test] }
  validates :status, presence: true,
                     inclusion: { in: %w[running completed failed] }
  validates :started_at, presence: true
  validates :finished_at, presence: true, if: -> { completed? || failed? }
  validates :duration_seconds, presence: true, if: -> { finished_at.present? }

  scope :running, -> { where(status: "running") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :manual, -> { where(trigger_type: "manual") }
  scope :scheduled, -> { where(trigger_type: "scheduled") }
  scope :recent, -> { order(started_at: :desc) }
  scope :by_feature, ->(feature) { where(feature_key: feature) }
  scope :by_config, ->(config_id) { where(tenant_integration_configuration_id: config_id) }
  scope :today, -> { where("started_at >= ?", Time.current.beginning_of_day) }
  scope :this_week, -> { where("started_at >= ?", Time.current.beginning_of_week) }

  before_create :set_started_at

  def running?
    status == "running"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def finished?
    completed? || failed?
  end

  # Marcar como completada
  def mark_as_completed!
    update!(
      status: "completed",
      finished_at: Time.current,
      duration_seconds: calculate_duration
    )
  end

  # Marcar como fallida
  def mark_as_failed!(error_msg)
    update!(
      status: "failed",
      finished_at: Time.current,
      duration_seconds: calculate_duration,
      error_message: error_msg
    )
  end

  # Actualizar estadísticas
  def update_statistics!(stats)
    update!(
      records_fetched: stats[:fetched] || 0,
      records_processed: stats[:processed] || 0,
      records_failed: stats[:failed] || 0,
      records_skipped: stats[:skipped] || 0
    )
  end

  # Calcular tasa de éxito
  def success_rate
    return 0 if records_fetched.zero?
    ((records_processed.to_f / records_fetched) * 100).round(2)
  end

  # Verificar si hubo errores
  def has_errors?
    records_failed > 0
  end

  # Verificar si hubo duplicados
  def has_duplicates?
    (duplicate_records || 0) > 0
  end

  # Resumen de la ejecución
  def summary
    {
      id: id,
      feature: feature_key,
      status: status,
      duration: duration_seconds,
      success_rate: "#{success_rate}%",
      stats: {
        fetched: records_fetched,
        processed: records_processed,
        failed: records_failed,
        skipped: records_skipped,
        duplicates: duplicate_records || 0
      }
    }
  end

  # Descripción legible
  def description
    provider = integration_provider_name
    feature = I18n.t("features.#{feature_key}", default: feature_key.humanize)
    trigger = I18n.t("triggers.#{trigger_type}", default: trigger_type.humanize)

    "#{provider} - #{feature} (#{trigger})"
  end

  # Obtener raw_data con errores
  def failed_raw_data
    integration_raw_data.where(processing_status: "failed")
  end

  # Obtener raw_data pendientes
  def pending_raw_data
    integration_raw_data.where(processing_status: "pending")
  end

  private

  def set_started_at
    self.started_at ||= Time.current
  end

  def calculate_duration
    return nil unless started_at && finished_at
    (finished_at - started_at).to_i
  end
end
