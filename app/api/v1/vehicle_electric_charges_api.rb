# app/api/v1/vehicle_electric_charges.rb
module V1
  class VehicleElectricChargesApi < Grape::API
    resource :electric_charges, desc: "Cargas eléctricas de vehículos" do
      desc "Listar todas las cargas eléctricas" do
        detail "Retorna cargas eléctricas con filtros opcionales"
        success Entities::VehicleElectricChargeSummaryEntity
      end
      params do
        optional :vehicle_id, type: Integer, desc: "Filtrar por vehículo"
        optional :tenant_id, type: Integer, desc: "Filtrar por tenant"
        optional :from_date, type: Date, desc: "Fecha desde"
        optional :to_date, type: Date, desc: "Fecha hasta"
        optional :charge_type, type: String, values: %w[AC DC], desc: "Filtrar por tipo de carga"
        optional :page, type: Integer, default: 1
        optional :per_page, type: Integer, default: 100, values: 1..500
      end
      get do
        charges = VehicleElectricCharge
          .includes(:vehicle, :tenant)
          .recent

        charges = charges.by_vehicle(params[:vehicle_id]) if params[:vehicle_id]
        charges = charges.by_tenant(params[:tenant_id]) if params[:tenant_id]
        charges = charges.where(charge_type: params[:charge_type]) if params[:charge_type]

        if params[:from_date] && params[:to_date]
          charges = charges.between_dates(params[:from_date], params[:to_date])
        end

        total = charges.count

        charges = charges
          .offset((params[:page] - 1) * params[:per_page])
          .limit(params[:per_page])

        {
          charges: Entities::VehicleElectricChargeSummaryEntity.represent(charges),
          pagination: {
            current_page: params[:page],
            per_page: params[:per_page],
            total_items: total,
            total_pages: (total.to_f / params[:per_page]).ceil
          }
        }
      end

      desc "Obtener detalle de una carga eléctrica" do
        success Entities::VehicleElectricChargeEntity
      end
      params do
        requires :id, type: Integer
      end
      get ":id" do
        charge = VehicleElectricCharge.find(params[:id])

        present charge,
                with: Entities::VehicleElectricChargeEntity,
                include_computed: true,
                include_vehicle: true,
                include_raw_data: true
      rescue ActiveRecord::RecordNotFound
        error!({
          error: "not_found",
          message: "Carga eléctrica no encontrada"
        }, 404)
      end

      desc "Obtener estadísticas de cargas eléctricas" do
        detail "Retorna estadísticas agregadas de cargas"
      end
      params do
        optional :vehicle_id, type: Integer
        optional :tenant_id, type: Integer
        optional :from_date, type: Date
        optional :to_date, type: Date
      end
      get "statistics" do
        charges = VehicleElectricCharge.all

        # Aplicar filtros
        charges = charges.by_vehicle(params[:vehicle_id]) if params[:vehicle_id]
        charges = charges.by_tenant(params[:tenant_id]) if params[:tenant_id]

        if params[:from_date] && params[:to_date]
          charges = charges.between_dates(params[:from_date], params[:to_date])
        end

        {
          total_charges: charges.count,
          total_energy_kwh: charges.total_energy,
          average_energy_kwh: charges.average_energy,
          total_duration_hours: charges.total_duration_hours,
          by_charge_type: charges.count_by_charge_type,
          period: {
            from: params[:from_date] || charges.minimum(:charge_start_time),
            to: params[:to_date] || charges.maximum(:charge_start_time)
          }
        }
      end
    end
  end
end
