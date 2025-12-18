# app/models/integration_provider.rb
class IntegrationProvider < ApplicationRecord
  belongs_to :integration_category
  has_one :integration_auth_schema, dependent: :destroy
  has_many :integration_features, dependent: :destroy
  has_many :tenant_integration_configurations, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true,
                   length: { maximum: 50 },
                   uniqueness: true,
                   format: { with: /\A[a-z0-9_]+\z/, message: "solo permite minúsculas, números y guiones bajos" }
  validates :status, presence: true,
                     inclusion: { in: %w[active coming_soon deprecated beta] }
  validates :api_base_url, length: { maximum: 500 }, allow_blank: true
  validates :logo_url, length: { maximum: 500 }, allow_blank: true
  validates :website_url, length: { maximum: 500 }, allow_blank: true
  validates :display_order, presence: true, numericality: { only_integer: true }

  scope :active, -> { where(is_active: true) }
  scope :by_status, ->(status) { where(status: status) }
  scope :premium, -> { where(is_premium: true) }
  scope :free, -> { where(is_premium: false) }
  scope :ordered, -> { order(display_order: :asc, name: :asc) }
  scope :for_marketplace, -> { active.where(status: [ "active", "beta" ]).ordered }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  def available?
    is_active && status.in?([ "active", "beta" ])
  end

  def ready_for_production?
    is_active && status == "active"
  end

  def configured_by_tenant?(tenant)
    tenant_integration_configurations.exists?(tenant: tenant)
  end

  def active_configurations_count
    tenant_integration_configurations.active.count
  end

  private

  def generate_slug
    self.slug = name.parameterize.underscore
  end
end
