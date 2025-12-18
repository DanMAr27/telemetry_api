# app/models/integration_feature.rb
class IntegrationFeature < ApplicationRecord
  belongs_to :integration_provider

  validates :feature_key, presence: true,
                          length: { maximum: 50 },
                          format: { with: /\A[a-z0-9_]+\z/, message: "solo permite minúsculas, números y guiones bajos" },
                          uniqueness: { scope: :integration_provider_id }
  validates :feature_name, presence: true, length: { maximum: 100 }
  validates :display_order, presence: true, numericality: { only_integer: true }

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(display_order: :asc, feature_name: :asc) }

  def available?
    is_active
  end
end
