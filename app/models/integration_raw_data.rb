# app/models/integration_raw_data.rb
class IntegrationRawData < ApplicationRecord
  belongs_to :integration_sync_execution
  belongs_to :tenant_integration_configuration
  belongs_to :normalized_record, polymorphic: true, optional: true

  delegate :tenant, :integration_provider, to: :tenant_integration_configuration

  validates :provider_slug, presence: true
  validates :feature_key, presence: true
  validates :external_id, presence: true
  validates :raw_data, presence: true
  validates :processing_status, presence: true,
                                inclusion: { in: %w[pending normalized failed duplicate skipped] }

  scope :pending, -> { where(processing_status: "pending") }
  scope :normalized, -> { where(processing_status: "normalized") }
  scope :failed, -> { where(processing_status: "failed") }
  scope :duplicate, -> { where(processing_status: "duplicate") }
  scope :skipped, -> { where(processing_status: "skipped") }
  scope :normalizable, -> { where(processing_status: %w[pending failed]) }
  scope :by_feature, ->(feature) { where(feature_key: feature) }
  scope :by_provider, ->(provider) { where(provider_slug: provider) }
  scope :by_execution, ->(execution_id) { where(integration_sync_execution_id: execution_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :with_errors, -> { failed.order(created_at: :desc) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :by_status, ->(status) { where(processing_status: status) }
  scope :retriable, -> {
    where(processing_status: "failed").select { |r| r.retriable_error? }
  }
  scope :with_error_type, ->(error_type) {
    where(processing_status: "failed").select do |r|
      detect_error_type(r.normalization_error) == error_type
    end
  }

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

  def skipped?
    processing_status == "skipped"
  end

  def can_be_retried?
    failed? && retriable_error?
  end

  def mark_as_skipped!(reason)
    update!(
      processing_status: "skipped",
      normalization_error: reason,
      metadata: (self.metadata || {}).merge(  # ← self.metadata
        skip_reason: reason,
        skipped_at: Time.current.iso8601
      )
    )
  end

  def reset_for_reprocessing!
    update!(
      processing_status: "pending",
      normalized_record_type: nil,
      normalized_record_id: nil,
      normalization_error: nil,
      normalized_at: nil
    )
  end

  def permanent_error?
    !retriable_error?
  end

  def error_type
    return nil unless failed?
    return "unknown_error" if normalization_error.blank?

    case normalization_error
    when /vehicle mapping not found/i
      "vehicle_mapping_missing"
    when /vehicle not found/i
      "vehicle_not_found"
    when /invalid data format/i
      "invalid_data_format"
    when /missing required field/i
      "missing_required_field"
    else
      "unknown_error"
    end
  end

  def raw_field(key)
    raw_data&.dig(key.to_s)
  end

  def has_raw_field?(key)
    raw_data&.key?(key.to_s)
  end

  def description
    "#{provider_slug}/#{feature_key} - #{external_id[0..10]}..."
  end

  # Estadísticas por estado
  def self.count_by_status
    group(:processing_status).count
  end

  def self.error_summary
    failed.group(:normalization_error).count
      .sort_by { |_, count| -count }
      .first(10)
  end

  # Detectar si el error es recuperable
  def retriable_error?
    return false unless normalization_error.present?

    retriable_patterns = [
      /vehicle mapping not found/i,
      /vehicle not found/i,
      /timeout/i,
      /connection/i,
      /temporary/i
    ]

    retriable_patterns.any? { |pattern| normalization_error.match?(pattern) }
  end

  # Verificar si puede ser normalizado
  def can_be_normalized?
    [ "pending", "failed" ].include?(processing_status)
  end

  # Verificar si puede ser omitido
  def can_be_skipped?
    [ "pending", "failed" ].include?(processing_status)
  end

  # Verificar si puede ser reseteado
  def can_be_reset?
    [ "failed", "skipped", "duplicate" ].include?(processing_status)
  end

  # Calcular duración de procesamiento
  def processing_duration_ms
    return nil unless normalized_at && created_at
    ((normalized_at - created_at) * 1000).round
  end

  # Obtener registro normalizado (polimórfico)
  def normalized_record
    return nil unless normalized_record_type && normalized_record_id
    normalized_record_type.constantize.find_by(id: normalized_record_id)
  rescue NameError
    nil
  end

  # Marcar como fallido con información adicional
  def mark_as_failed!(error_msg, error_type: nil)
    update!(
      processing_status: "failed",
      normalization_error: error_msg,
      normalized_at: Time.current,
      metadata: (self.metadata || {}).merge(
        error_type: error_type || self.class.detect_error_type(error_msg),
        failed_at: Time.current.iso8601,
        retry_count: retry_count || 0
      )
    )
  end

  # Marcar como normalizado
  def mark_as_normalized!(normalized_record)
    update!(
      processing_status: "normalized",
      normalized_record_type: normalized_record.class.name,
      normalized_record_id: normalized_record.id,
      normalized_at: Time.current,
      normalization_error: nil,
      metadata: (self.metadata || {}).merge(
        normalized_at: Time.current.iso8601,
        processing_duration_ms: processing_duration_ms
      )
    )
  end

  # Marcar como duplicado
  def mark_as_duplicate!(original_id = nil)
    update!(
      processing_status: "duplicate",
      normalized_at: Time.current,
      metadata: (self.metadata || {}).merge(
        duplicate_of: original_id,
        duplicate_detected_at: Time.current.iso8601
      )
    )
  end

  # Encontrar el registro original (si es duplicado)
  def find_original_record
    return nil unless processing_status == "duplicate"

    duplicate_of_id = metadata&.dig("duplicate_of")
    return IntegrationRawData.find_by(id: duplicate_of_id) if duplicate_of_id

    # Si no está en metadata, buscar por external_id
    IntegrationRawData
      .where(
        tenant_integration_configuration_id: tenant_integration_configuration_id,
        external_id: external_id,
        processing_status: "normalized"
      )
      .where.not(id: id)
      .first
  end

  # Encontrar registros similares (con el mismo error)
  def find_similar_failed_records(limit: 5)
    return [] unless processing_status == "failed"

    key_error = self.class.extract_key_error_part(normalization_error)

    IntegrationRawData
      .where(tenant_integration_configuration_id: tenant_integration_configuration_id)
      .where(processing_status: "failed")
      .where.not(id: id)
      .where("normalization_error LIKE ?", "%#{key_error}%")
      .limit(limit)
  end

  class << self
    # Detectar tipo de error desde mensaje
    def detect_error_type(error_message)
      return "unknown" unless error_message.present?

      error_msg = error_message.downcase

      case error_msg
      when /vehicle mapping not found|vehicle not found/
        "vehicle_not_found"
      when /authentication|credentials|unauthorized/
        "authentication_error"
      when /device.*reassign|external.*changed/
        "device_reassignment"
      when /invalid.*format/
        "invalid_data_format"
      when /missing.*field|required field/
        "missing_required_field"
      when /duplicate/
        "duplicate_detection"
      when /timeout|timed out/
        "timeout_error"
      when /connection/
        "connection_error"
      else
        "normalization_error"
      end
    end

    # Extraer parte clave del error
    def extract_key_error_part(error_message)
      return "" unless error_message

      # Si contiene "vehicle mapping", extraer el external_id
      if error_message.include?("mapping not found")
        match = error_message.match(/external_id[:\s]+([a-zA-Z0-9_-]+)/)
        return "external_id: #{match[1]}" if match
      end

      # Si es otro tipo de error, tomar las primeras palabras clave
      error_message.split(":").first&.strip || error_message[0..50]
    end

    # Crear o manejar duplicado (mejorado)
    def create_or_handle_duplicate(attributes)
      # Extraer IDs de forma segura (pueden venir como objetos ActiveRecord o como IDs directos)
      config_id = attributes[:tenant_integration_configuration]&.id ||
                  attributes[:tenant_integration_configuration_id]

      existing = find_by(
        tenant_integration_configuration_id: config_id,
        external_id: attributes[:external_id],
        feature_key: attributes[:feature_key]
      )

      if existing
        # Si existe y tiene datos diferentes, podría ser actualización
        if existing.raw_data != attributes[:raw_data]
          # Hay cambios → reprocesar si ya fue normalizado
          if existing.processing_status == "normalized"
            existing.update!(
              raw_data: attributes[:raw_data],
              processing_status: "pending",
              normalized_record_type: nil,
              normalized_record_id: nil,
              metadata: (existing.metadata || {}).merge(
                updated_from_sync: Time.current.iso8601,
                previous_normalized_at: existing.normalized_at
              )
            )
            existing
          else
            # Ya estaba pending o failed, solo actualizar datos
            existing.update!(raw_data: attributes[:raw_data])
            existing
          end
        else
          # Verdadero duplicado sin cambios → NO crear registro, devolver nil
          Rails.logger.debug("  ⊘ Duplicado idéntico detectado: #{attributes[:external_id]}")
          nil
        end
      else
        # No existe, crear nuevo
        begin
          create!(attributes)
        rescue ActiveRecord::RecordNotUnique
          # Race condition: otro proceso lo creó justo ahora
          Rails.logger.debug("  ⊘ Duplicado por race condition: #{attributes[:external_id]}")
          nil
        end
      end
    end

    # Estadísticas rápidas
    def quick_stats(scope = all)
      {
        total: scope.count,
        pending: scope.where(processing_status: "pending").count,
        normalized: scope.where(processing_status: "normalized").count,
        failed: scope.where(processing_status: "failed").count,
        duplicate: scope.where(processing_status: "duplicate").count,
        skipped: scope.where(processing_status: "skipped").count
      }
    end
  end
end
