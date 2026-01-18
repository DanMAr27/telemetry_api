module V1
  class VehicleKmsApi < Grape::API
    resource :vehicle_kms do
      desc "List vehicle kms"
      params do
        optional :vehicle_id, type: Integer, desc: "Filter by vehicle"
        optional :page, type: Integer, default: 1
        optional :per_page, type: Integer, default: 20
      end
      get do
        scope = VehicleKm.kept
        scope = scope.where(vehicle_id: params[:vehicle_id]) if params[:vehicle_id].present?

        present scope.order(input_date: :desc).page(params[:page]).per(params[:per_page]), with: Entities::VehicleKmEntity
      end

      desc "Create a vehicle km entry"
      params do
        requires :vehicle_id, type: Integer, desc: "Vehicle ID"
        requires :input_date, type: Date, desc: "Reading date"
        requires :km_reported, type: Integer, desc: "Odometer reading"
        optional :correction_notes, type: String, desc: "Notes"
      end
      post do
        vehicle = Vehicle.find(params[:vehicle_id])

        # We can use the service here
        result = VehicleKmManager.new(vehicle).register_reading(
          input_date: params[:input_date],
          km_reported: params[:km_reported],
          status: :original # Explicitly calling strict manual entry distinct? or just use default logic
          # The manager currently sets status: :original by default.
        )

        if result.success?
          present result.data, with: Entities::VehicleKmEntity
        else
          error!(result.errors, 422)
        end
      end
    end
  end
end
