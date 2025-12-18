# app/models/integration_raw_data.rb
class IntegrationRawData < ApplicationRecord
  belongs_to :integration_sync_execution
  belongs_to :tenant_integration_configuration
  belongs_to :normalized_record,
             polymorphic: true,
             optional: true


  delegate :tenant, :integration_provider, to: :tenant_integration_configuration

  validates :provider_slug, presence: true
  validates :feature_key, presence: true
  validates :external_id, presence: true
  validates :raw_data, presence: true
  validates :processing_status, presence: true,
                                inclusion: { in: %w[pending normalized failed duplicate] }
  validates :external_id, uniqueness: {
    scope: [ :tenant_integration_configuration_id, :provider_slug, :feature_key ],
    message: "ya existe para esta configuración"
  }

  scope :pending, -> { where(processing_status: "pending") }
  scope :normalized, -> { where(processing_status: "normalized") }
  scope :failed, -> { where(processing_status: "failed") }
  scope :duplicate, -> { where(processing_status: "duplicate") }
  scope :by_feature, ->(feature) { where(feature_key: feature) }
  scope :by_provider, ->(provider) { where(provider_slug: provider) }
  scope :by_execution, ->(execution_id) { where(integration_sync_execution_id: execution_id) }
  scope :recent, -> { order(created_at: :desc) }

  def pending?
    processing_status == "pending"
  end

  def normalized?
    processing_status == "normalized"
  end

  def failed?
    processing_status == "failed"
  end

  def duplicate?
    processing_status == "duplicate"
  end

  # Marcar como normalizado
  def mark_as_normalized!(record)
    update!(
      processing_status: "normalized",
      normalized_record: record,
      normalized_at: Time.current,
      normalization_error: nil
    )
  end

  # Marcar como fallido
  def mark_as_failed!(error_msg)
    update!(
      processing_status: "failed",
      normalization_error: error_msg,
      normalized_at: Time.current
    )
  end

  # Marcar como duplicado
  def mark_as_duplicate!
    update!(processing_status: "duplicate")
  end

  # Resetear para reprocesar
  def reset_for_reprocessing!
    update!(
      processing_status: "pending",
      normalized_record_type: nil,
      normalized_record_id: nil,
      normalization_error: nil,
      normalized_at: nil
    )
  end

  # Acceso a campos del raw_data
  def raw_field(key)
    raw_data&.dig(key.to_s)
  end

  # Verificar si tiene un campo
  def has_raw_field?(key)
    raw_data&.key?(key.to_s)
  end

  # Descripción legible
  def description
    "#{provider_slug}/#{feature_key} - #{external_id[0..10]}..."
  end

  # Crear o marcar como duplicado
  def self.create_or_mark_duplicate(attributes)
    create!(attributes)
  rescue ActiveRecord::RecordNotUnique
    # Si el índice UNIQUE detecta duplicado, buscamos el registro
    existing = find_by(
      tenant_integration_configuration_id: attributes[:tenant_integration_configuration_id],
      provider_slug: attributes[:provider_slug],
      feature_key: attributes[:feature_key],
      external_id: attributes[:external_id]
    )
    existing&.mark_as_duplicate!
    existing
  end

  # Contar por estado
  def self.count_by_status
    group(:processing_status).count
  end
end
