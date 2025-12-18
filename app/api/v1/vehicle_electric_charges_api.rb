# app/api/v1/vehicle_electric_charges.rb
module V1
  class VehicleElectricChargesApi < Grape::API
    helpers do
      def current_tenant
        @current_tenant ||= Tenant.find(params[:tenant_id])
      end
    end

    resource :tenants do
      route_param :tenant_id do
        resource :vehicles do
          route_param :vehicle_id do
            resource :electric_charges do
              desc "Listar cargas eléctricas de un vehículo"
              params do
                optional :from_date, type: Date
                optional :to_date, type: Date
                optional :charge_type, type: String, values: %w[AC DC]
                optional :limit, type: Integer, default: 100
              end
              get do
                vehicle = current_tenant.vehicles.find(params[:vehicle_id])

                charges = vehicle.vehicle_electric_charges.recent

                if params[:from_date] && params[:to_date]
                  charges = charges.between_dates(params[:from_date], params[:to_date])
                end

                charges = charges.where(charge_type: params[:charge_type]) if params[:charge_type]
                charges = charges.limit(params[:limit])

                present charges,
                        with: Entities::VehicleElectricChargeEntity,
                        include_computed: true
              end
              desc "Detalle de una carga eléctrica"
              params do
                requires :id, type: Integer
              end
              get ":id" do
                vehicle = current_tenant.vehicles.find(params[:vehicle_id])
                charge = vehicle.vehicle_electric_charges.find(params[:id])

                present charge,
                        with: Entities::VehicleElectricChargeEntity,
                        include_computed: true,
                        include_raw_data: true
              end
            end
          end
        end
        resource :electric_charges do
          desc "Listar todas las cargas eléctricas del tenant"
          params do
            optional :from_date, type: Date
            optional :to_date, type: Date
            optional :vehicle_id, type: Integer
            optional :charge_type, type: String, values: %w[AC DC]
            optional :limit, type: Integer, default: 100
          end
          get do
            charges = VehicleElectricCharge.by_tenant(current_tenant.id).recent

            if params[:from_date] && params[:to_date]
              charges = charges.between_dates(params[:from_date], params[:to_date])
            end

            charges = charges.by_vehicle(params[:vehicle_id]) if params[:vehicle_id]
            charges = charges.where(charge_type: params[:charge_type]) if params[:charge_type]
            charges = charges.limit(params[:limit])

            present charges, with: Entities::VehicleElectricChargeSummaryEntity
          end
        end
      end
    end
  end
end
