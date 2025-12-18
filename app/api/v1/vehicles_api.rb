# app/api/v1/vehicles.rb
module V1
  class VehiclesApi < Grape::API
    helpers do
      def current_tenant
        @current_tenant ||= Tenant.find(params[:tenant_id])
      end
    end

    resource :tenants do
      route_param :tenant_id do
        resource :vehicles do
          # ================================================================
          # GET /api/v1/tenants/:tenant_id/vehicles
          # Listar vehículos del tenant
          # ================================================================
          desc "Listar vehículos del tenant"
          params do
            optional :status, type: String, values: Vehicle.statuses
            optional :fuel_type, type: String, values: Vehicle.fuel_types
            optional :vehicle_type, type: String, values: Vehicle.vehicle_types
            optional :is_electric, type: Boolean
            optional :with_telemetry, type: Boolean, default: false
          end
          get do
            vehicles = current_tenant.vehicles

            vehicles = vehicles.where(status: params[:status]) if params[:status]
            vehicles = vehicles.by_fuel_type(params[:fuel_type]) if params[:fuel_type]
            vehicles = vehicles.where(vehicle_type: params[:vehicle_type]) if params[:vehicle_type]
            vehicles = vehicles.where(is_electric: params[:is_electric]) unless params[:is_electric].nil?

            if params[:with_telemetry]
              vehicles = current_tenant.vehicles_with_telemetry
            end

            vehicles = vehicles.by_name

            present vehicles, with: Entities::VehicleEntity
          end

          # ================================================================
          # GET /api/v1/tenants/:tenant_id/vehicles/:id
          # Obtener detalle de un vehículo
          # ================================================================
          desc "Obtener detalle de un vehículo"
          params do
            requires :id, type: Integer
          end
          get ":id" do
            vehicle = current_tenant.vehicles.find(params[:id])
            present vehicle,
                    with: Entities::VehicleEntity,
                    include_telemetry: true,
                    include_statistics: true
          end

          # ================================================================
          # POST /api/v1/tenants/:tenant_id/vehicles
          # Crear vehículo
          # ================================================================
          desc "Crear vehículo"
          params do
            requires :name, type: String
            requires :license_plate, type: String
            optional :vin, type: String
            optional :brand, type: String
            optional :model, type: String
            optional :year, type: Integer
            optional :vehicle_type, type: String, values: Vehicle.vehicle_types
            optional :fuel_type, type: String, values: Vehicle.fuel_types
            optional :tank_capacity_liters, type: Float
            optional :battery_capacity_kwh, type: Float
            optional :initial_odometer_km, type: Float
            optional :acquisition_date, type: Date
            optional :metadata, type: Hash, default: {}
          end
          post do
            vehicle = current_tenant.vehicles.build(declared(params, include_missing: false))

            if vehicle.save
              present vehicle, with: Entities::VehicleEntity
            else
              error!({ error: "validation_error", message: vehicle.errors.full_messages.join(", ") }, 422)
            end
          end

          # ================================================================
          # PUT /api/v1/tenants/:tenant_id/vehicles/:id
          # Actualizar vehículo
          # ================================================================
          desc "Actualizar vehículo"
          params do
            requires :id, type: Integer
            optional :name, type: String
            optional :license_plate, type: String
            optional :vin, type: String
            optional :brand, type: String
            optional :model, type: String
            optional :year, type: Integer
            optional :vehicle_type, type: String
            optional :fuel_type, type: String
            optional :status, type: String, values: Vehicle.statuses
            optional :tank_capacity_liters, type: Float
            optional :battery_capacity_kwh, type: Float
            optional :current_odometer_km, type: Float
            optional :last_maintenance_date, type: Date
            optional :next_maintenance_date, type: Date
            optional :metadata, type: Hash
          end
          put ":id" do
            vehicle = current_tenant.vehicles.find(params[:id])

            if vehicle.update(declared(params, include_missing: false))
              present vehicle, with: Entities::VehicleEntity
            else
              error!({ error: "validation_error", message: vehicle.errors.full_messages.join(", ") }, 422)
            end
          end

          # ================================================================
          # DELETE /api/v1/tenants/:tenant_id/vehicles/:id
          # Eliminar vehículo
          # ================================================================
          desc "Eliminar vehículo"
          params do
            requires :id, type: Integer
          end
          delete ":id" do
            vehicle = current_tenant.vehicles.find(params[:id])

            if vehicle.destroy
              { success: true, message: "Vehículo eliminado exitosamente" }
            else
              error!({ error: "deletion_error", message: vehicle.errors.full_messages.join(", ") }, 422)
            end
          end
        end
      end
    end
  end
end
