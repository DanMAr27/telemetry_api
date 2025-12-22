# app/api/v1/vehicles_api.rb
module V1
  class VehiclesApi < Grape::API
    resource :vehicles do
      desc "Listar todos los vehículos" do
        detail "Retorna lista de vehículos con filtros opcionales"
        success Entities::VehicleEntity
      end
      params do
        optional :tenant_id, type: Integer, desc: "Filtrar por tenant"
        optional :status, type: String, values: %w[active maintenance inactive sold],
                 desc: "Filtrar por estado"
        optional :fuel_type, type: String,
                 values: %w[diesel gasoline electric hybrid lpg cng hydrogen],
                 desc: "Filtrar por tipo de combustible"
        optional :vehicle_type, type: String, values: %w[car van truck motorcycle bus],
                 desc: "Filtrar por tipo de vehículo"
        optional :is_electric, type: Boolean, desc: "Filtrar eléctricos/combustión"
        optional :with_telemetry, type: Boolean, default: false,
                 desc: "Solo vehículos con telemetría activa"
        optional :brand, type: String, desc: "Filtrar por marca"
        optional :search, type: String, desc: "Buscar por nombre o matrícula"

        optional :page, type: Integer, default: 1
        optional :per_page, type: Integer, default: 50, values: 1..100

        optional :sort_by, type: String, values: %w[name license_plate created_at],
                 default: "name", desc: "Campo para ordenar"
        optional :sort_order, type: String, values: %w[asc desc],
                 default: "asc", desc: "Dirección del ordenamiento"
      end
      get do
        vehicles = Vehicle.includes(:tenant)

        vehicles = vehicles.where(tenant_id: params[:tenant_id]) if params[:tenant_id]
        vehicles = vehicles.where(status: params[:status]) if params[:status]
        vehicles = vehicles.by_fuel_type(params[:fuel_type]) if params[:fuel_type]
        vehicles = vehicles.where(vehicle_type: params[:vehicle_type]) if params[:vehicle_type]
        vehicles = vehicles.where(is_electric: params[:is_electric]) unless params[:is_electric].nil?
        vehicles = vehicles.by_brand(params[:brand]) if params[:brand]
        if params[:with_telemetry]
          vehicles = vehicles
            .joins(:vehicle_provider_mappings)
            .where(vehicle_provider_mappings: { is_active: true })
            .distinct
        end

        if params[:search].present?
          search_term = "%#{params[:search]}%"
          vehicles = vehicles.where(
            "name ILIKE ? OR license_plate ILIKE ?",
            search_term, search_term
          )
        end

        order_clause = case params[:sort_by]
        when "created_at"
                        "created_at #{params[:sort_order]}"
        when "license_plate"
                        "license_plate #{params[:sort_order]}"
        else
                        "name #{params[:sort_order]}"
        end
        vehicles = vehicles.order(Arel.sql(order_clause))

        total = vehicles.count

        vehicles = vehicles
          .offset((params[:page] - 1) * params[:per_page])
          .limit(params[:per_page])

        {
          vehicles: Entities::VehicleEntity.represent(vehicles),
          pagination: {
            current_page: params[:page],
            per_page: params[:per_page],
            total_items: total,
            total_pages: (total.to_f / params[:per_page]).ceil
          }
        }
      end

      desc "Crear nuevo vehículo" do
        detail "Crea un vehículo en el sistema"
        success Entities::VehicleEntity
      end
      params do
        requires :tenant_id, type: Integer, desc: "ID del tenant propietario"
        requires :name, type: String, desc: "Nombre descriptivo del vehículo"
        requires :license_plate, type: String, desc: "Matrícula del vehículo"

        optional :vin, type: String, desc: "VIN (Vehicle Identification Number)"
        optional :brand, type: String, desc: "Marca (Ford, Mercedes, Tesla, etc.)"
        optional :model, type: String, desc: "Modelo del vehículo"
        optional :year, type: Integer, desc: "Año de fabricación"
        optional :vehicle_type, type: String, values: %w[car van truck motorcycle bus],
                 desc: "Tipo de vehículo"
        optional :fuel_type, type: String,
                 values: %w[diesel gasoline electric hybrid lpg cng hydrogen],
                 desc: "Tipo de combustible/energía"
        optional :tank_capacity_liters, type: Float, desc: "Capacidad del tanque (L)"
        optional :battery_capacity_kwh, type: Float, desc: "Capacidad de batería (kWh)"
        optional :initial_odometer_km, type: Float, desc: "Kilometraje inicial"
        optional :acquisition_date, type: Date, desc: "Fecha de adquisición"
        optional :metadata, type: Hash, default: {}, desc: "Metadata adicional"
      end
      post do
        tenant = Tenant.find(params[:tenant_id])

        vehicle = tenant.vehicles.build(
          declared(params, include_missing: false).except(:tenant_id)
        )

        if vehicle.save
          present vehicle,
                  with: Entities::VehicleEntity,
                  include_telemetry: true
        else
          error!({
            error: "validation_error",
            message: vehicle.errors.full_messages.join(", "),
            details: vehicle.errors.messages
          }, 422)
        end
      rescue ActiveRecord::RecordNotFound
        error!({
          error: "not_found",
          message: "Tenant no encontrado"
        }, 404)
      end

      desc "Obtener opciones disponibles para crear/editar vehículos" do
        detail "Retorna listas de valores válidos para los campos"
      end
      get "options" do
        {
          fuel_types: Vehicle.fuel_types.map { |type|
            { value: type, label: type.humanize }
          },
          vehicle_types: Vehicle.vehicle_types.map { |type|
            { value: type, label: type.humanize }
          },
          statuses: Vehicle.statuses.map { |status|
            { value: status, label: status.humanize }
          }
        }
      end

      desc "Obtener resumen de la flota de vehículos" do
        detail "Retorna estadísticas agregadas de todos los vehículos"
      end
      params do
        optional :tenant_id, type: Integer, desc: "Filtrar por tenant"
      end
      get "summary" do
        vehicles = Vehicle.all
        vehicles = vehicles.where(tenant_id: params[:tenant_id]) if params[:tenant_id]

        {
          total_vehicles: vehicles.count,
          by_status: vehicles.group(:status).count,
          by_fuel_type: vehicles.group(:fuel_type).count,
          by_vehicle_type: vehicles.group(:vehicle_type).count,
          electric_vehicles: vehicles.electric.count,
          combustion_vehicles: vehicles.combustion.count,
          with_telemetry: vehicles.joins(:vehicle_provider_mappings)
            .where(vehicle_provider_mappings: { is_active: true })
            .distinct.count,
          needs_maintenance: vehicles.select(&:needs_maintenance?).count
        }
      end

      route_param :id do
        desc "Obtener detalle de un vehículo" do
          detail "Retorna información completa de un vehículo"
          success Entities::VehicleEntity
        end
        params do
          optional :include_telemetry, type: Boolean, default: true
          optional :include_statistics, type: Boolean, default: true
          optional :include_recent_activity, type: Boolean, default: false
        end
        get do
          vehicle = Vehicle.find(params[:id])

          entity_options = {
            include_telemetry: params[:include_telemetry],
            include_statistics: params[:include_statistics]
          }

          response = Entities::VehicleEntity.represent(vehicle, entity_options).as_json

          if params[:include_recent_activity]
            response[:recent_activity] = {
              last_refueling: vehicle.vehicle_refuelings.recent.first&.refueling_date,
              last_charge: vehicle.vehicle_electric_charges.recent.first&.charge_start_time,
              refuelings_last_30_days: vehicle.vehicle_refuelings
                .where("refueling_date >= ?", 30.days.ago).count,
              charges_last_30_days: vehicle.vehicle_electric_charges
                .where("charge_start_time >= ?", 30.days.ago).count
            }
          end

          response
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Vehículo no encontrado"
          }, 404)
        end

        desc "Actualizar vehículo" do
          detail "Actualiza la información de un vehículo"
          success Entities::VehicleEntity
        end
        params do
          optional :name, type: String
          optional :license_plate, type: String
          optional :vin, type: String
          optional :brand, type: String
          optional :model, type: String
          optional :year, type: Integer
          optional :vehicle_type, type: String, values: %w[car van truck motorcycle bus]
          optional :fuel_type, type: String,
                   values: %w[diesel gasoline electric hybrid lpg cng hydrogen]
          optional :status, type: String, values: %w[active maintenance inactive sold]
          optional :tank_capacity_liters, type: Float
          optional :battery_capacity_kwh, type: Float
          optional :current_odometer_km, type: Float
          optional :last_maintenance_date, type: Date
          optional :next_maintenance_date, type: Date
          optional :metadata, type: Hash
        end
        put do
          vehicle = Vehicle.find(params[:id])

          if vehicle.update(declared(params, include_missing: false))
            present vehicle,
                    with: Entities::VehicleEntity,
                    include_telemetry: true
          else
            error!({
              error: "validation_error",
              message: vehicle.errors.full_messages.join(", ")
            }, 422)
          end
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Vehículo no encontrado"
          }, 404)
        end

        desc "Eliminar vehículo" do
          detail "Elimina un vehículo del sistema"
        end
        delete do
          vehicle = Vehicle.find(params[:id])

          if vehicle.destroy
            { success: true, message: "Vehículo eliminado exitosamente" }
          else
            error!({
              error: "deletion_error",
              message: vehicle.errors.full_messages.join(", ")
            }, 422)
          end
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Vehículo no encontrado"
          }, 404)
        end

        desc "Activar vehículo" do
          detail "Cambia el estado del vehículo a 'active'"
        end
        post "activate" do
          vehicle = Vehicle.find(params[:id])
          vehicle.update!(status: "active")

          present vehicle, with: Entities::VehicleEntity
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Vehículo no encontrado"
          }, 404)
        end

        desc "Poner vehículo en mantenimiento" do
          detail "Cambia el estado del vehículo a 'maintenance'"
        end
        post "set-maintenance" do
          vehicle = Vehicle.find(params[:id])
          vehicle.update!(status: "maintenance")

          present vehicle, with: Entities::VehicleEntity
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Vehículo no encontrado"
          }, 404)
        end

        desc "Desactivar vehículo" do
          detail "Cambia el estado del vehículo a 'inactive'"
        end
        post "deactivate" do
          vehicle = Vehicle.find(params[:id])
          vehicle.update!(status: "inactive")

          present vehicle, with: Entities::VehicleEntity
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Vehículo no encontrado"
          }, 404)
        end

        desc "Obtener estado de telemetría del vehículo" do
          detail "Retorna información sobre la telemetría activa"
        end
        get "telemetry-status" do
          vehicle = Vehicle.find(params[:id])

          active_mappings = vehicle.vehicle_provider_mappings.active

          {
            vehicle_id: vehicle.id,
            has_telemetry: vehicle.has_telemetry?,
            active_mappings_count: active_mappings.count,
            providers: active_mappings.map do |mapping|
              {
                provider_id: mapping.integration_provider.id,
                provider_name: mapping.integration_provider.name,
                provider_slug: mapping.integration_provider.slug,
                external_vehicle_id: mapping.external_vehicle_id,
                external_vehicle_name: mapping.external_vehicle_name,
                mapped_at: mapping.mapped_at,
                last_sync_at: mapping.last_sync_at
              }
            end
          }
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Vehículo no encontrado"
          }, 404)
        end

        desc "Listar repostajes del vehículo" do
          detail "Retorna el historial de repostajes"
        end
        params do
          optional :from_date, type: Date, desc: "Fecha desde"
          optional :to_date, type: Date, desc: "Fecha hasta"
          optional :limit, type: Integer, default: 100, values: 1..500
        end
        get "refuelings" do
          vehicle = Vehicle.find(params[:id])

          refuelings = vehicle.vehicle_refuelings.recent

          # Aplicar filtros de fecha
          if params[:from_date] && params[:to_date]
            refuelings = refuelings.between_dates(params[:from_date], params[:to_date])
          end

          refuelings = refuelings.limit(params[:limit])

          present refuelings,
                  with: Entities::VehicleRefuelingEntity,
                  include_computed: true
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Vehículo no encontrado"
          }, 404)
        end

        desc "Listar cargas eléctricas del vehículo" do
          detail "Retorna el historial de cargas (solo vehículos eléctricos)"
        end
        params do
          optional :from_date, type: Date
          optional :to_date, type: Date
          optional :charge_type, type: String, values: %w[AC DC]
          optional :limit, type: Integer, default: 100, values: 1..500
        end
        get "electric-charges" do
          vehicle = Vehicle.find(params[:id])

          # Verificar que sea eléctrico
          unless vehicle.electric?
            error!({
              error: "invalid_vehicle_type",
              message: "Este vehículo no es eléctrico",
              vehicle_fuel_type: vehicle.fuel_type
            }, 422)
          end

          charges = vehicle.vehicle_electric_charges.recent

          # Aplicar filtros
          if params[:from_date] && params[:to_date]
            charges = charges.between_dates(params[:from_date], params[:to_date])
          end

          charges = charges.where(charge_type: params[:charge_type]) if params[:charge_type]
          charges = charges.limit(params[:limit])

          present charges,
                  with: Entities::VehicleElectricChargeEntity,
                  include_computed: true
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Vehículo no encontrado"
          }, 404)
        end

        desc "Obtener estadísticas del vehículo" do
          detail "Retorna métricas y estadísticas de uso"
        end
        params do
          optional :from_date, type: Date, desc: "Fecha desde"
          optional :to_date, type: Date, desc: "Fecha hasta"
        end
        get "statistics" do
          vehicle = Vehicle.find(params[:id])

          from_date = params[:from_date] || 30.days.ago.to_date
          to_date = params[:to_date] || Date.current

          stats = {
            vehicle_id: vehicle.id,
            vehicle_name: vehicle.name,
            license_plate: vehicle.license_plate,
            period: {
              from: from_date,
              to: to_date,
              days: (to_date - from_date).to_i + 1
            }
          }

          if vehicle.electric?
            charges = vehicle.vehicle_electric_charges
              .where("charge_start_time BETWEEN ? AND ?", from_date.beginning_of_day, to_date.end_of_day)

            stats[:electric] = {
              total_charges: charges.count,
              total_energy_kwh: charges.sum(:energy_consumed_kwh).to_f.round(2),
              average_energy_per_charge_kwh: charges.average(:energy_consumed_kwh).to_f.round(2),
              total_charge_time_minutes: charges.sum(:duration_minutes).to_i,
              fast_charges_count: charges.where(charge_type: "DC").count,
              slow_charges_count: charges.where(charge_type: "AC").count
            }
          else
            refuelings = vehicle.vehicle_refuelings
              .where("refueling_date BETWEEN ? AND ?", from_date.beginning_of_day, to_date.end_of_day)

            stats[:fuel] = {
              total_refuelings: refuelings.count,
              total_liters: refuelings.sum(:volume_liters).to_f.round(2),
              total_cost: refuelings.sum(:cost).to_f.round(2),
              average_liters_per_refueling: refuelings.average(:volume_liters).to_f.round(2),
              average_cost_per_liter: (refuelings.sum(:cost) / refuelings.sum(:volume_liters)).to_f.round(2)
            }
          end

          if vehicle.current_odometer_km && vehicle.initial_odometer_km
            stats[:odometer] = {
              initial_km: vehicle.initial_odometer_km,
              current_km: vehicle.current_odometer_km,
              total_km_driven: vehicle.total_km_driven
            }
          end

          stats
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Vehículo no encontrado"
          }, 404)
        end
      end
    end
  end
end
