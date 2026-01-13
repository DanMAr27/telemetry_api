class FuelType < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true

  enum :energy_group, {
    fuel: 0,
    electric: 1,
    other: 2
  }, prefix: :energy

  has_many :vehicle_refuelings
  has_many :product_catalogs
end
