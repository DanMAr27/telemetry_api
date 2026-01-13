# app/api/v1/vehicle_mappings_api.rb
module V1
  class VehicleProviderMappingsApi < Grape::API
    resource :vehicle_mappings, desc: "Mapeos entre vehículos internos y proveedores de telemetría" do
      desc "Listar todos los mapeos de vehículos" do
        detail "Retorna mapeos entre vehículos y proveedores de telemetría"
        success Entities::VehicleProviderMappingEntity
      end
      params do
        optional :integration_id, type: Integer, desc: "Filtrar por configuración de integración"
        optional :vehicle_id, type: Integer, desc: "Filtrar por vehículo"
        optional :tenant_id, type: Integer, desc: "Filtrar por tenant"
        optional :active_only, type: Boolean, default: false, desc: "Solo mapeos activos"
        optional :page, type: Integer, default: 1
        optional :per_page, type: Integer, default: 50, values: 1..100
      end
      get do
        mappings = VehicleProviderMapping.includes(:vehicle, :tenant_integration_configuration)

        if params[:integration_id]
          mappings = mappings.where(tenant_integration_configuration_id: params[:integration_id])
        end

        mappings = mappings.where(vehicle_id: params[:vehicle_id]) if params[:vehicle_id]
        mappings = mappings.active if params[:active_only]

        if params[:tenant_id]
          mappings = mappings
            .joins(tenant_integration_configuration: :tenant)
            .where(tenants: { id: params[:tenant_id] })
        end

        total = mappings.count

        mappings = mappings
          .offset((params[:page] - 1) * params[:per_page])
          .limit(params[:per_page])

        {
          mappings: Entities::VehicleProviderMappingEntity.represent(mappings),
          pagination: {
            current_page: params[:page],
            per_page: params[:per_page],
            total_items: total,
            total_pages: (total.to_f / params[:per_page]).ceil
          }
        }
      end

      desc "Listar dispositivos descubiertos no asignados" do
        detail "Lista dispositivos recibidos en RawData que no tienen un mapeo activo actualmente"
      end
      params do
        requires :tenant_id, type: Integer, desc: "ID del Tenant"
        optional :provider_slug, type: String, desc: "Filtrar por proveedor (geotab, etc)"
        optional :days_lookback, type: Integer, default: 30, desc: "Días hacia atrás para buscar"
      end
      get "unmapped" do
        tenant = Tenant.find(params[:tenant_id])
        result = Integrations::VehicleMappings::ListUnmappedDevicesService.new(
          tenant,
          params[:provider_slug],
          params[:days_lookback]
        ).call

        if result.success?
          result.data
        else
          error!({ error: "list_error", message: result.errors.join(", ") }, 422)
        end
      end



      route_param :id do
        desc "Obtener detalle de un mapeo" do
          success Entities::VehicleProviderMappingEntity
        end
        get do
          mapping = VehicleProviderMapping.find(params[:id])
          present mapping, with: Entities::VehicleProviderMappingEntity
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Mapeo no encontrado"
          }, 404)
        end

        desc "Actualizar mapeo" do
          success Entities::VehicleProviderMappingEntity
        end
        params do
          optional :external_vehicle_name, type: String
          optional :external_metadata, type: Hash
        end
        put do
          mapping = VehicleProviderMapping.find(params[:id])

          if mapping.update(declared(params, include_missing: false))
            present mapping, with: Entities::VehicleProviderMappingEntity
          else
            error!({
              error: "validation_error",
              message: mapping.errors.full_messages.join(", ")
            }, 422)
          end
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Mapeo no encontrado"
          }, 404)
        end
      end
    end
  end
end
