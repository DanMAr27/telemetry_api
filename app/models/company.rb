# app/models/company.rb
class Company < ApplicationRecord
  # Associations
  has_many :vehicles, dependent: :destroy
  has_many :telemetry_credentials, dependent: :destroy
  has_many :telemetry_providers, through: :telemetry_credentials

  # Validations
  validates :name, presence: true
  validates :tax_id, uniqueness: true, allow_nil: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }

  # Instance methods
  def active_vehicles
    vehicles.active
  end

  def vehicles_with_telemetry
    vehicles.with_telemetry
  end

  def vehicles_without_telemetry
    vehicles.without_telemetry
  end

  def has_telemetry_provider?(provider_slug)
    telemetry_credentials.joins(:telemetry_provider)
                        .where(telemetry_providers: { slug: provider_slug })
                        .active
                        .exists?
  end

  def telemetry_credential_for(provider_slug)
    telemetry_credentials.joins(:telemetry_provider)
                        .where(telemetry_providers: { slug: provider_slug })
                        .active
                        .first
  end
end
