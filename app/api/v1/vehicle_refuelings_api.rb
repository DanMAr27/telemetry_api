# app/api/v1/vehicle_refuelings.rb
module V1
  class VehicleRefuelingsApi < Grape::API
    helpers do
      def current_tenant
        @current_tenant ||= Tenant.find(params[:tenant_id])
      end
    end

    resource :tenants do
      route_param :tenant_id do
        resource :vehicles do
          route_param :vehicle_id do
            resource :refuelings do
              desc "Listar repostajes de un vehículo"
              params do
                optional :from_date, type: Date
                optional :to_date, type: Date
                optional :limit, type: Integer, default: 100
              end
              get do
                vehicle = current_tenant.vehicles.find(params[:vehicle_id])

                refuelings = vehicle.vehicle_refuelings.recent

                if params[:from_date] && params[:to_date]
                  refuelings = refuelings.between_dates(params[:from_date], params[:to_date])
                end

                refuelings = refuelings.limit(params[:limit])

                present refuelings,
                        with: Entities::VehicleRefuelingEntity,
                        include_computed: true
              end
              desc "Detalle de un repostaje"
              params do
                requires :id, type: Integer
              end
              get ":id" do
                vehicle = current_tenant.vehicles.find(params[:vehicle_id])
                refueling = vehicle.vehicle_refuelings.find(params[:id])

                present refueling,
                        with: Entities::VehicleRefuelingEntity,
                        include_computed: true,
                        include_raw_data: true
              end
            end
          end
        end
        resource :refuelings do
          desc "Listar todos los repostajes del tenant"
          params do
            optional :from_date, type: Date
            optional :to_date, type: Date
            optional :vehicle_id, type: Integer
            optional :fuel_type, type: String
            optional :limit, type: Integer, default: 100
          end
          get do
            refuelings = VehicleRefueling.by_tenant(current_tenant.id).recent

            if params[:from_date] && params[:to_date]
              refuelings = refuelings.between_dates(params[:from_date], params[:to_date])
            end

            refuelings = refuelings.by_vehicle(params[:vehicle_id]) if params[:vehicle_id]
            refuelings = refuelings.by_fuel_type(params[:fuel_type]) if params[:fuel_type]
            refuelings = refuelings.limit(params[:limit])

            present refuelings, with: Entities::VehicleRefuelingSummaryEntity
          end
        end
      end
    end
  end
end
