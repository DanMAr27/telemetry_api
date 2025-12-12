# app/models/telemetry_provider.rb
class TelemetryProvider < ApplicationRecord
  # Associations
  has_many :telemetry_credentials, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :api_base_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }

  # Class methods
  def self.find_by_slug!(slug)
    find_by!(slug: slug)
  end

  # Instance methods
  def activate!
    update!(is_active: true)
  end

  def deactivate!
    update!(is_active: false)
  end

  def geotab?
    slug == "geotab"
  end
end
