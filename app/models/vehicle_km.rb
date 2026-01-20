class VehicleKm < ApplicationRecord
  include Discard::Model

  belongs_to :vehicle
  belongs_to :source_record, polymorphic: true, optional: true

  enum :status, { original: 0, corrected: 1, edited: 2, conflicted: 3 }

  validates :input_date, presence: true
  validates :km_reported, presence: true
  validates :status, presence: true
end
