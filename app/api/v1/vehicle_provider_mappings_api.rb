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

      desc "Crear nuevo mapeo vehículo-proveedor" do
        detail "Mapea un vehículo interno con un ID de vehículo del proveedor"
        success Entities::VehicleProviderMappingEntity
      end
      params do
        requires :integration_configuration_id, type: Integer,
                 desc: "ID de la configuración de integración"
        requires :vehicle_id, type: Integer, desc: "ID del vehículo interno"
        requires :external_vehicle_id, type: String, desc: "ID del vehículo en el proveedor"
        optional :external_vehicle_name, type: String, desc: "Nombre del vehículo en el proveedor"
        optional :external_metadata, type: Hash, default: {},
                 desc: "Metadata adicional del proveedor"
      end
      post do
        config = TenantIntegrationConfiguration.find(params[:integration_configuration_id])
        vehicle = Vehicle.find(params[:vehicle_id])

        unless vehicle.tenant_id == config.tenant_id
          error!({
            error: "tenant_mismatch",
            message: "El vehículo y la configuración deben pertenecer al mismo tenant"
          }, 422)
        end

        result = Integrations::VehicleMappings::CreateMappingService.new(
          config,
          vehicle,
          params[:external_vehicle_id],
          params[:external_vehicle_name]
        ).call

        if result.success?
          present result.data, with: Entities::VehicleProviderMappingEntity
        else
          error!({
            error: "validation_error",
            message: result.errors.join(", ")
          }, 422)
        end
      rescue ActiveRecord::RecordNotFound => e
        error!({
          error: "not_found",
          message: e.message
        }, 404)
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

        desc "Eliminar mapeo" do
          detail "Elimina permanentemente un mapeo vehículo-proveedor"
        end
        delete do
          mapping = VehicleProviderMapping.find(params[:id])

          if mapping.destroy
            { success: true, message: "Mapeo eliminado exitosamente" }
          else
            error!({
              error: "deletion_error",
              message: mapping.errors.full_messages.join(", ")
            }, 422)
          end
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Mapeo no encontrado"
          }, 404)
        end

        desc "Activar mapeo" do
          detail "Activa el mapeo para permitir sincronización de datos"
        end
        post "activate" do
          mapping = VehicleProviderMapping.find(params[:id])
          mapping.activate!

          present mapping, with: Entities::VehicleProviderMappingEntity
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Mapeo no encontrado"
          }, 404)
        end

        desc "Desactivar mapeo" do
          detail "Desactiva el mapeo. No se sincronizarán más datos para este vehículo."
        end
        post "deactivate" do
          mapping = VehicleProviderMapping.find(params[:id])
          mapping.deactivate!

          present mapping, with: Entities::VehicleProviderMappingEntity
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
