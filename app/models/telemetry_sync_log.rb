# app/models/telemetry_sync_log.rb
class TelemetrySyncLog < ApplicationRecord
  # Associations
  belongs_to :telemetry_credential
  belongs_to :vehicle, optional: true
  has_many :telemetry_normalization_errors, dependent: :destroy

  # Validations
  validates :sync_type, presence: true, inclusion: { in: %w[refuels charges odometer trips full] }
  validates :status, presence: true, inclusion: { in: %w[success error partial pending] }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { where(status: "success") }
  scope :failed, -> { where(status: "error") }
  scope :partial, -> { where(status: "partial") }
  scope :for_provider, ->(provider_slug) {
    joins(telemetry_credential: :telemetry_provider)
      .where(telemetry_providers: { slug: provider_slug })
  }
  scope :for_sync_type, ->(type) { where(sync_type: type) }
  scope :today, -> { where("DATE(created_at) = ?", Date.current) }

  # Instance methods
  def success?
    status == "success"
  end

  def error?
    status == "error"
  end

  def partial?
    status == "partial"
  end

  def duration_seconds
    return nil if started_at.nil? || completed_at.nil?
    completed_at - started_at
  end

  def has_errors?
    telemetry_normalization_errors.any?
  end

  def error_count
    telemetry_normalization_errors.count
  end

  def success_rate_percent
    return 0 if records_processed.zero?
    ((records_created.to_f / records_processed) * 100).round(2)
  end
end
