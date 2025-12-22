# app/api/v1/vehicle_refuelings.rb
module V1
  class VehicleRefuelingsApi < Grape::API
    resource :refuelings, desc: "Repostajes de combustible" do
      desc "Listar todos los repostajes" do
        detail "Retorna repostajes de combustible con filtros opcionales"
        success Entities::VehicleRefuelingSummaryEntity
      end
      params do
        optional :vehicle_id, type: Integer, desc: "Filtrar por vehículo"
        optional :tenant_id, type: Integer, desc: "Filtrar por tenant"
        optional :from_date, type: Date, desc: "Fecha desde"
        optional :to_date, type: Date, desc: "Fecha hasta"
        optional :fuel_type, type: String, desc: "Filtrar por tipo de combustible"
        optional :limit, type: Integer, default: 100, values: 1..500
        optional :page, type: Integer, default: 1
        optional :per_page, type: Integer, default: 100, values: 1..500
      end
      get do
        refuelings = VehicleRefueling
          .includes(:vehicle, :tenant)
          .recent

        refuelings = refuelings.by_vehicle(params[:vehicle_id]) if params[:vehicle_id]
        refuelings = refuelings.by_tenant(params[:tenant_id]) if params[:tenant_id]
        refuelings = refuelings.by_fuel_type(params[:fuel_type]) if params[:fuel_type]

        if params[:from_date] && params[:to_date]
          refuelings = refuelings.between_dates(params[:from_date], params[:to_date])
        end

          total = refuelings.count

        refuelings = refuelings
          .offset((params[:page] - 1) * params[:per_page])
          .limit(params[:per_page])

        {
          refuelings: Entities::VehicleRefuelingSummaryEntity.represent(refuelings),
          pagination: {
            current_page: params[:page],
            per_page: params[:per_page],
            total_items: total,
            total_pages: (total.to_f / params[:per_page]).ceil
          }
        }
      end

      desc "Obtener detalle de un repostaje" do
        success Entities::VehicleRefuelingEntity
      end
      params do
        requires :id, type: Integer
      end
      get ":id" do
        refueling = VehicleRefueling.find(params[:id])

        present refueling,
                with: Entities::VehicleRefuelingEntity,
                include_computed: true,
                include_vehicle: true,
                include_raw_data: true
      rescue ActiveRecord::RecordNotFound
        error!({
          error: "not_found",
          message: "Repostaje no encontrado"
        }, 404)
      end

      desc "Obtener estadísticas de repostajes" do
        detail "Retorna estadísticas agregadas de repostajes"
      end
      params do
        optional :vehicle_id, type: Integer
        optional :tenant_id, type: Integer
        optional :from_date, type: Date
        optional :to_date, type: Date
      end
      get "statistics" do
        refuelings = VehicleRefueling.all

        # Aplicar filtros
        refuelings = refuelings.by_vehicle(params[:vehicle_id]) if params[:vehicle_id]
        refuelings = refuelings.by_tenant(params[:tenant_id]) if params[:tenant_id]

        if params[:from_date] && params[:to_date]
          refuelings = refuelings.between_dates(params[:from_date], params[:to_date])
        end

        {
          total_refuelings: refuelings.count,
          total_liters: refuelings.total_volume,
          total_cost: refuelings.total_cost,
          average_liters_per_refueling: refuelings.average_volume,
          by_fuel_type: refuelings.count_by_fuel_type,
          period: {
            from: params[:from_date] || refuelings.minimum(:refueling_date),
            to: params[:to_date] || refuelings.maximum(:refueling_date)
          }
        }
      end
    end
  end
end
