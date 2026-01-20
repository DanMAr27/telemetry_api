module Entities
  class VehicleKmEntity < Grape::Entity
    expose :id
    expose :vehicle_id
    expose :input_date
    expose :km_reported
    expose :km_normalized
    expose :status
    expose :correction_notes
    expose :conflict_reasons
    expose :created_at
    expose :updated_at
    expose :source_record_type
    expose :source_record_id
  end
end
