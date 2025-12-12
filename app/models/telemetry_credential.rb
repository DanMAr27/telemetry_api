# app/models/telemetry_credential.rb
class TelemetryCredential < ApplicationRecord
  # Encriptación (requiere gem 'attr_encrypted' o Rails 7+ encrypts)
  # Opción 1: attr_encrypted gem
  # attr_encrypted :credentials, key: Rails.application.credentials.dig(:encryption, :key)
  attr_encrypted :credentials, key: ENV["ENCRYPTION_KEY"]

  # Opción 2: Rails 7+ (comentar si usas attr_encrypted)
  # encrypts :credentials

  # Associations
  belongs_to :company
  belongs_to :telemetry_provider
  has_many :vehicle_telemetry_configs, dependent: :destroy
  has_many :vehicles, through: :vehicle_telemetry_configs
  has_many :telemetry_sync_logs, dependent: :destroy

  # Validations
  validates :company_id, uniqueness: { scope: :telemetry_provider_id,
                                       message: "already has credentials for this provider" }
  validates :credentials, presence: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :for_provider, ->(provider_slug) {
    joins(:telemetry_provider).where(telemetry_providers: { slug: provider_slug })
  }
  scope :needs_sync, -> {
    where("last_sync_at IS NULL OR last_sync_at < ?", 1.hour.ago)
  }

  # Instance methods
  def credentials_hash
    # Deserializa las credenciales encriptadas
    JSON.parse(credentials).with_indifferent_access
  rescue JSON::ParserError
    {}
  end

  def update_sync_timestamp!(successful: true)
    attributes = { last_sync_at: Time.current }
    attributes[:last_successful_sync_at] = Time.current if successful
    update!(attributes)
  end

  def provider_name
    telemetry_provider.slug
  end

  def from_date_for_sync
    # Fecha desde la cual sincronizar (última exitosa o 30 días atrás)
    last_successful_sync_at || 30.days.ago
  end
end
