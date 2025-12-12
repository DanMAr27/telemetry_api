# app/models/telemetry_normalization_error.rb
class TelemetryNormalizationError < ApplicationRecord
  # Associations
  belongs_to :telemetry_sync_log

  # Validations
  validates :error_type, presence: true, inclusion: { in: %w[validation_error mapping_error data_format_error unknown] }
  validates :error_message, presence: true
  validates :raw_data, presence: true

  # Scopes
  scope :unresolved, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(error_type: type) }
  scope :by_provider, ->(provider) { where(provider_name: provider) }

  # Instance methods
  def resolve!(notes = nil)
    update!(
      resolved: true,
      resolved_at: Time.current,
      resolution_notes: notes
    )
  end

  def mark_unresolved!
    update!(
      resolved: false,
      resolved_at: nil,
      resolution_notes: nil
    )
  end

  def raw_data_hash
    raw_data.is_a?(String) ? JSON.parse(raw_data) : raw_data
  rescue JSON::ParserError
    {}
  end
end
