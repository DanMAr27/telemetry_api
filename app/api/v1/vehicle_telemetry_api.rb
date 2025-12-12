# app/api/v1/vehicle_telemetry_api.rb
module V1
  class VehicleTelemetryApi < Grape::API
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

      def find_vehicle!
        vehicle = current_company.vehicles.find(params[:vehicle_id])
        error!("Vehicle not found", 404) unless vehicle
        vehicle
      end
    end

    resource :companies do
      route_param :company_id do
        resource :vehicles do
          route_param :vehicle_id do
            # Configuración de telemetría del vehículo
            namespace :telemetry_config do
              desc "Get vehicle telemetry configuration",
                   success: Entities::VehicleTelemetryConfigEntity,
                   tags: [ "Vehicle Telemetry" ]
              get do
                authorize_company!
                vehicle = find_vehicle!

                config = vehicle.vehicle_telemetry_config
                error!("No telemetry configuration found", 404) unless config

                present config, with: Entities::VehicleTelemetryConfigEntity, include_credential: true
              end

              desc "Create or update vehicle telemetry configuration",
                   success: Entities::VehicleTelemetryConfigEntity,
                   tags: [ "Vehicle Telemetry" ]
              params do
                requires :telemetry_credential_id, type: Integer, desc: "Credential ID"
                requires :external_device_id, type: String, desc: "Device ID in provider system"
                optional :sync_frequency, type: String, values: %w[manual hourly daily weekly], default: "daily"
                optional :data_types, type: Array[String], default: %w[refuels charges odometer]
                optional :is_active, type: Boolean, default: true
              end
              post do
                authorize_company!
                vehicle = find_vehicle!

                # Verificar que la credencial pertenece a la empresa
                credential = current_company.telemetry_credentials.find(params[:telemetry_credential_id])

                config = vehicle.vehicle_telemetry_config || vehicle.build_vehicle_telemetry_config

                config.assign_attributes(
                  telemetry_credential_id: credential.id,
                  external_device_id: params[:external_device_id],
                  sync_frequency: params[:sync_frequency],
                  data_types: params[:data_types],
                  is_active: params[:is_active]
                )

                if config.save
                  present config, with: Entities::VehicleTelemetryConfigEntity, include_credential: true
                else
                  error!(config.errors.full_messages, 422)
                end
              end

              desc "Delete vehicle telemetry configuration",
                   tags: [ "Vehicle Telemetry" ]
              delete do
                authorize_company!
                vehicle = find_vehicle!

                config = vehicle.vehicle_telemetry_config
                error!("No configuration to delete", 404) unless config

                config.destroy
                { success: true, message: "Configuration deleted" }
              end
            end

            # Datos de repostajes
            namespace :refuels do
              desc "Get vehicle refuels",
                   success: Entities::RefuelEntity,
                   is_array: true,
                   tags: [ "Vehicle Telemetry" ]
              params do
                optional :from_date, type: Date, desc: "Filter from date"
                optional :to_date, type: Date, desc: "Filter to date"
                optional :page, type: Integer, default: 1
                optional :per_page, type: Integer, default: 50
                optional :include_calculations, type: Boolean, default: false
                optional :include_anomalies, type: Boolean, default: false
              end
              get do
                authorize_company!
                vehicle = find_vehicle!

                refuels = vehicle.refuels.recent
                refuels = refuels.in_date_range(params[:from_date], params[:to_date]) if params[:from_date] && params[:to_date]
                refuels = refuels.page(params[:page]).per(params[:per_page])

                present refuels, with: Entities::RefuelEntity,
                        include_calculations: params[:include_calculations],
                        include_anomalies: params[:include_anomalies]
              end

              desc "Get refuel statistics",
                   tags: [ "Vehicle Telemetry" ]
              params do
                optional :from_date, type: Date, desc: "Filter from date"
                optional :to_date, type: Date, desc: "Filter to date"
              end
              get :stats do
                authorize_company!
                vehicle = find_vehicle!

                refuels = vehicle.refuels
                refuels = refuels.in_date_range(params[:from_date], params[:to_date]) if params[:from_date] && params[:to_date]

                {
                  total_refuels: refuels.count,
                  total_liters: refuels.sum(:volume_liters).round(2),
                  total_cost: refuels.sum(:cost).round(2),
                  average_volume: refuels.average(:volume_liters)&.round(2),
                  average_cost: refuels.average(:cost)&.round(2),
                  anomalies_count: refuels.select { |r| r.exceeds_tank_capacity? }.count
                }
              end
            end

            # Datos de cargas eléctricas
            namespace :charges do
              desc "Get vehicle electric charges",
                   success: Entities::ElectricChargeEntity,
                   is_array: true,
                   tags: [ "Vehicle Telemetry" ]
              params do
                optional :from_date, type: Date, desc: "Filter from date"
                optional :to_date, type: Date, desc: "Filter to date"
                optional :charge_type, type: String, values: %w[AC DC], desc: "Filter by charge type"
                optional :page, type: Integer, default: 1
                optional :per_page, type: Integer, default: 50
                optional :include_calculations, type: Boolean, default: false
                optional :include_anomalies, type: Boolean, default: false
              end
              get do
                authorize_company!
                vehicle = find_vehicle!

                charges = vehicle.electric_charges.recent
                charges = charges.in_date_range(params[:from_date], params[:to_date]) if params[:from_date] && params[:to_date]
                charges = charges.where(charge_type: params[:charge_type]) if params[:charge_type]
                charges = charges.page(params[:page]).per(params[:per_page])

                present charges, with: Entities::ElectricChargeEntity,
                        include_calculations: params[:include_calculations],
                        include_anomalies: params[:include_anomalies]
              end

              desc "Get charge statistics",
                   tags: [ "Vehicle Telemetry" ]
              params do
                optional :from_date, type: Date, desc: "Filter from date"
                optional :to_date, type: Date, desc: "Filter to date"
              end
              get :stats do
                authorize_company!
                vehicle = find_vehicle!

                charges = vehicle.electric_charges
                charges = charges.in_date_range(params[:from_date], params[:to_date]) if params[:from_date] && params[:to_date]

                {
                  total_charges: charges.count,
                  total_kwh: charges.sum(:energy_consumed_kwh).round(3),
                  total_duration_minutes: charges.sum(:duration_minutes),
                  average_kwh: charges.average(:energy_consumed_kwh)&.round(3),
                  average_duration_minutes: charges.average(:duration_minutes)&.round(2),
                  ac_charges: charges.ac_charges.count,
                  dc_charges: charges.dc_charges.count
                }
              end
            end
          end
        end
      end
    end
  end
end
