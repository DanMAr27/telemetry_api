# app/services/integrations/marketplace/setup_integration_service.rb
module Integrations
  module Marketplace
    class SetupIntegrationService
      def initialize(tenant, provider_slug, params)
        @tenant = tenant
        @provider_slug = provider_slug
        @params = params
      end

      def call
        # PASO 1: Validar proveedor
        provider = validate_provider
        return provider unless provider.is_a?(IntegrationProvider)

        # PASO 2: Validar que el tenant no tenga ya este proveedor
        existing = check_existing_configuration(provider)
        return existing if existing.failure?

        # PASO 3: Validar estructura de credenciales
        validation = validate_credentials_structure(provider)
        return validation if validation.failure?

        # PASO 4: (OPCIONAL) Probar conexión si se solicita
        if @params[:test_connection_first]
          connection_test = test_connection_before_create(provider)
          return connection_test if connection_test.failure?
        end

        # PASO 5: Crear configuración (inactiva)
        config = create_configuration(provider)
        return config if config.failure?

        # PASO 6: (OPCIONAL) Activar inmediatamente si se solicita
        if @params[:activate_immediately]
          activation = activate_configuration(config.data)
          return activation if activation.failure?
        end

        # PASO 7: Retornar resultado exitoso
        ServiceResult.success(
          data: config.data,
          message: build_success_message(config.data)
        )

      rescue StandardError => e
        Rails.logger.error("Error en SetupIntegrationService: #{e.message}")
        ServiceResult.failure(
          errors: [ "Error al configurar integración: #{e.message}" ]
        )
      end

      private

      def validate_provider
        provider = IntegrationProvider.for_marketplace.find_by(slug: @provider_slug)

        unless provider
          return ServiceResult.failure(
            errors: [ "Proveedor '#{@provider_slug}' no encontrado o no disponible" ]
          )
        end

        unless provider.integration_auth_schema&.is_active
          return ServiceResult.failure(
            errors: [ "El proveedor no tiene configuración de autenticación disponible" ]
          )
        end

        provider
      end

      def check_existing_configuration(provider)
        existing = @tenant.tenant_integration_configurations.find_by(
          integration_provider: provider
        )

        if existing
          return ServiceResult.failure(
            errors: [ "Ya existe una configuración para este proveedor" ],
            data: { existing_configuration_id: existing.id }
          )
        end

        ServiceResult.success
      end

      def validate_credentials_structure(provider)
        credentials = @params[:credentials]

        unless credentials.is_a?(Hash) && credentials.present?
          return ServiceResult.failure(
            errors: [ "Las credenciales son requeridas" ]
          )
        end

        schema = provider.integration_auth_schema
        required_fields = schema.required_fields.map { |f| f["name"] }
        provided_fields = credentials.keys.map(&:to_s)

        missing_fields = required_fields - provided_fields

        if missing_fields.any?
          return ServiceResult.failure(
            errors: [ "Faltan campos requeridos: #{missing_fields.join(', ')}" ]
          )
        end

        ServiceResult.success
      end


      def test_connection_before_create(provider)
        Rails.logger.info("→ Probando conexión antes de crear configuración...")

        result = TenantConfigurations::TestConnectionService.new(
          provider.id,
          @params[:credentials]
        ).call

        unless result.success?
          return ServiceResult.failure(
            errors: [ "Test de conexión falló: #{result.errors.join(', ')}" ]
          )
        end

        Rails.logger.info("✓ Test de conexión exitoso")
        ServiceResult.success
      end

      def create_configuration(provider)
        config = @tenant.tenant_integration_configurations.build(
          integration_provider: provider,
          credentials: @params[:credentials],
          enabled_features: @params[:enabled_features] || [],
          sync_frequency: @params[:sync_frequency] || "daily",
          sync_hour: @params[:sync_hour] || 2,
          sync_day_of_week: @params[:sync_day_of_week],
          sync_day_of_month: @params[:sync_day_of_month],
          sync_config: @params[:sync_config] || {},
          is_active: false # Siempre empieza inactiva
        )

        if config.save
          Rails.logger.info("✓ Configuración creada (ID: #{config.id})")
          ServiceResult.success(data: config)
        else
          ServiceResult.failure(
            errors: config.errors.full_messages
          )
        end
      end

      def activate_configuration(config)
        # Validar que tenga al menos una feature habilitada
        unless config.enabled_features.any?
          return ServiceResult.failure(
            errors: [ "Debe seleccionar al menos una funcionalidad antes de activar" ]
          )
        end

        if config.update(is_active: true, activated_at: Time.current)
          Rails.logger.info("✓ Configuración activada")
          ServiceResult.success(data: config)
        else
          ServiceResult.failure(
            errors: config.errors.full_messages
          )
        end
      end

       def build_success_message(config)
        base = "Integración con #{config.integration_provider.name} configurada exitosamente"

        if config.is_active
          "#{base} y activada"
        else
          "#{base}. Recuerda activarla para comenzar a sincronizar"
        end
      end
    end
  end
end
