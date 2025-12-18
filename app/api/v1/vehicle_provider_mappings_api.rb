# app/api/v1/vehicle_provider_mappings.rb
module V1
  class VehicleProviderMappingsApi < Grape::API
    helpers do
      def current_tenant
        @current_tenant ||= Tenant.find(params[:tenant_id])
      end
    end

    resource :tenants do
      route_param :tenant_id do
        resource :integration_configurations do
          route_param :config_id do
            resource :vehicle_mappings do
              desc "Listar mapeos de vehículos para una configuración"
              params do
                optional :active_only, type: Boolean, default: false
              end
              get do
                config = current_tenant.tenant_integration_configurations.find(params[:config_id])
                mappings = config.vehicle_provider_mappings
                mappings = mappings.active if params[:active_only]

                present mappings, with: Entities::VehicleProviderMappingEntity
              end
              desc "Crear mapeo entre vehículo y proveedor"
              params do
                requires :vehicle_id, type: Integer
                requires :external_vehicle_id, type: String
                optional :external_vehicle_name, type: String
                optional :is_active, type: Boolean, default: true
                optional :external_metadata, type: Hash, default: {}
              end
              post do
                config = current_tenant.tenant_integration_configurations.find(params[:config_id])
                vehicle = current_tenant.vehicles.find(params[:vehicle_id])

                result = Integrations::VehicleMappings::CreateMappingService.new(
                  config,
                  vehicle,
                  params[:external_vehicle_id],
                  params[:external_vehicle_name]
                ).call

                if result.success?
                  present result.data, with: Entities::VehicleProviderMappingEntity
                else
                  error!({ error: "validation_error", message: result.errors.join(", ") }, 422)
                end
              end
              desc "Actualizar mapeo"
              params do
                requires :id, type: Integer
                optional :external_vehicle_name, type: String
                optional :external_metadata, type: Hash
              end
              put ":id" do
                config = current_tenant.tenant_integration_configurations.find(params[:config_id])
                mapping = config.vehicle_provider_mappings.find(params[:id])

                if mapping.update(declared(params, include_missing: false))
                  present mapping, with: Entities::VehicleProviderMappingEntity
                else
                  error!({ error: "validation_error", message: mapping.errors.full_messages.join(", ") }, 422)
                end
              end
              desc "Activar mapeo"
              params do
                requires :id, type: Integer
              end
              post ":id/activate" do
                config = current_tenant.tenant_integration_configurations.find(params[:config_id])
                mapping = config.vehicle_provider_mappings.find(params[:id])

                mapping.activate!
                present mapping, with: Entities::VehicleProviderMappingEntity
              end
              desc "Desactivar mapeo"
              params do
                requires :id, type: Integer
              end
              post ":id/deactivate" do
                config = current_tenant.tenant_integration_configurations.find(params[:config_id])
                mapping = config.vehicle_provider_mappings.find(params[:id])

                mapping.deactivate!
                present mapping, with: Entities::VehicleProviderMappingEntity
              end
              desc "Eliminar mapeo"
              params do
                requires :id, type: Integer
              end
              delete ":id" do
                config = current_tenant.tenant_integration_configurations.find(params[:config_id])
                mapping = config.vehicle_provider_mappings.find(params[:id])

                if mapping.destroy
                  { success: true, message: "Mapeo eliminado exitosamente" }
                else
                  error!({ error: "deletion_error", message: mapping.errors.full_messages.join(", ") }, 422)
                end
              end
            end
          end
        end
      end
    end
  end
end
