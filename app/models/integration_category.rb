# app/models/integration_category.rb
class IntegrationCategory < ApplicationRecord
  has_many :integration_providers, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true,
                   length: { maximum: 50 },
                   uniqueness: true,
                   format: { with: /\A[a-z0-9_]+\z/, message: "solo permite minúsculas, números y guiones bajos" }
  validates :icon, length: { maximum: 50 }, allow_blank: true
  validates :display_order, presence: true, numericality: { only_integer: true }

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(display_order: :asc, name: :asc) }
  scope :for_marketplace, -> { active.ordered }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  private

  def generate_slug
    self.slug = name.parameterize.underscore
  end
end
