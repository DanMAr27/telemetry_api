# app/services/integrations/tenant_configurations/create_service.rb
module Integrations
  module TenantConfigurations
    class CreateService
      def initialize(tenant, params)
        @tenant = tenant
        @params = params
      end

      def call
        # Verificar que el proveedor existe y está disponible
        provider = IntegrationProvider.for_marketplace.find_by(id: @params[:integration_provider_id])
        unless provider
          return ServiceResult.failure(errors: [ "Proveedor no encontrado o no disponible" ])
        end

        # Verificar que no exista ya una configuración para este proveedor
        existing = @tenant.tenant_integration_configurations
          .find_by(integration_provider_id: provider.id)

        if existing
          return ServiceResult.failure(
            errors: [ "Ya existe una configuración para este proveedor" ]
          )
        end

        # Crear configuración
        config = @tenant.tenant_integration_configurations.build(
          integration_provider: provider,
          credentials: @params[:credentials],
          enabled_features: @params[:enabled_features] || [],
          sync_frequency: @params[:sync_frequency] || "daily",
          sync_hour: @params[:sync_hour] || 2,
          sync_day_of_week: @params[:sync_day_of_week],
          sync_day_of_month: @params[:sync_day_of_month],
          sync_config: @params[:sync_config] || {},
          is_active: false # Inicia inactiva hasta que se valide
        )

        if config.save
          ServiceResult.success(
            data: config,
            message: "Configuración creada exitosamente"
          )
        else
          ServiceResult.failure(errors: config.errors.full_messages)
        end
      rescue StandardError => e
        Rails.logger.error("Error al crear configuración: #{e.message}")
        ServiceResult.failure(errors: [ "Error al crear la configuración" ])
      end
    end
  end
end
