# app/api/v1/vehicles_api.rb
module V1
  class VehiclesApi < Grape::API
    version "v1", using: :path
    format :json
    prefix :api

    helpers do
      def current_company
        Company.find(params[:company_id]) if params[:company_id]
      end

      def authorize_company!
        error!("Company not found", 404) unless current_company
      end
    end

    resource :companies do
      route_param :company_id do
        resource :vehicles do
          desc "List company vehicles",
               success: Entities::VehicleEntity,
               is_array: true,
               tags: [ "Vehicles" ]
          params do
            optional :active_only, type: Boolean, default: false
            optional :fuel_type, type: String, values: %w[combustion electric hybrid]
            optional :with_telemetry, type: Boolean, default: false
            optional :page, type: Integer, default: 1
            optional :per_page, type: Integer, default: 20
            optional :include_stats, type: Boolean, default: false
          end
          get do
            authorize_company!

            vehicles = current_company.vehicles
            vehicles = vehicles.active if params[:active_only]
            vehicles = vehicles.where(fuel_type: params[:fuel_type]) if params[:fuel_type]
            vehicles = vehicles.with_telemetry if params[:with_telemetry]

            vehicles = vehicles.page(params[:page]).per(params[:per_page])

            present vehicles, with: Entities::VehicleEntity, include_stats: params[:include_stats]
          end

          desc "Get vehicle details",
               success: Entities::VehicleEntity,
               tags: [ "Vehicles" ]
          params do
            requires :id, type: Integer, desc: "Vehicle ID"
            optional :include_telemetry_config, type: Boolean, default: false
            optional :include_stats, type: Boolean, default: false
          end
          route_param :id do
            get do
              authorize_company!

              vehicle = current_company.vehicles.find(params[:id])
              present vehicle, with: Entities::VehicleEntity,
                      include_telemetry_config: params[:include_telemetry_config],
                      include_stats: params[:include_stats]
            end
          end

          desc "Create a new vehicle",
               success: Entities::VehicleEntity,
               tags: [ "Vehicles" ]
          params do
            requires :name, type: String, desc: "Vehicle name"
            requires :license_plate, type: String, desc: "License plate"
            optional :vin, type: String, desc: "VIN"
            optional :brand, type: String, desc: "Brand"
            optional :model, type: String, desc: "Model"
            optional :year, type: Integer, desc: "Year"
            optional :fuel_type, type: String, values: %w[combustion electric hybrid]
            optional :tank_capacity_liters, type: Float, desc: "Tank capacity in liters"
            optional :battery_capacity_kwh, type: Float, desc: "Battery capacity in kWh"
            optional :is_active, type: Boolean, default: true
          end
          post do
            authorize_company!

            vehicle = current_company.vehicles.new(
              name: params[:name],
              license_plate: params[:license_plate],
              vin: params[:vin],
              brand: params[:brand],
              model: params[:model],
              year: params[:year],
              fuel_type: params[:fuel_type],
              tank_capacity_liters: params[:tank_capacity_liters],
              battery_capacity_kwh: params[:battery_capacity_kwh],
              is_active: params[:is_active]
            )

            if vehicle.save
              present vehicle, with: Entities::VehicleEntity
            else
              error!(vehicle.errors.full_messages, 422)
            end
          end

          desc "Update a vehicle",
               success: Entities::VehicleEntity,
               tags: [ "Vehicles" ]
          params do
            requires :id, type: Integer, desc: "Vehicle ID"
            optional :name, type: String
            optional :license_plate, type: String
            optional :vin, type: String
            optional :brand, type: String
            optional :model, type: String
            optional :year, type: Integer
            optional :fuel_type, type: String, values: %w[combustion electric hybrid]
            optional :tank_capacity_liters, type: Float
            optional :battery_capacity_kwh, type: Float
            optional :is_active, type: Boolean
          end
          route_param :id do
            put do
              authorize_company!

              vehicle = current_company.vehicles.find(params[:id])

              update_params = declared(params, include_missing: false).except(:id, :company_id)

              if vehicle.update(update_params)
                present vehicle, with: Entities::VehicleEntity
              else
                error!(vehicle.errors.full_messages, 422)
              end
            end
          end

          desc "Delete a vehicle",
               tags: [ "Vehicles" ]
          params do
            requires :id, type: Integer, desc: "Vehicle ID"
          end
          route_param :id do
            delete do
              authorize_company!

              vehicle = current_company.vehicles.find(params[:id])

              if vehicle.destroy
                { success: true, message: "Vehicle deleted successfully" }
              else
                error!(vehicle.errors.full_messages, 422)
              end
            end
          end

          desc "Get vehicles without telemetry configuration",
               success: Entities::VehicleEntity,
               is_array: true,
               tags: [ "Vehicles" ]
          params do
            optional :page, type: Integer, default: 1
            optional :per_page, type: Integer, default: 20
          end
          get :without_telemetry do
            authorize_company!

            vehicles = current_company.vehicles_without_telemetry
            vehicles = vehicles.page(params[:page]).per(params[:per_page])

            present vehicles, with: Entities::VehicleEntity
          end

          desc "Get vehicles with active telemetry",
               success: Entities::VehicleEntity,
               is_array: true,
               tags: [ "Vehicles" ]
          params do
            optional :page, type: Integer, default: 1
            optional :per_page, type: Integer, default: 20
          end
          get :with_telemetry do
            authorize_company!

            vehicles = current_company.vehicles_with_telemetry
            vehicles = vehicles.page(params[:page]).per(params[:per_page])

            present vehicles, with: Entities::VehicleEntity, include_telemetry_config: true
          end
        end
      end
    end
  end
end
