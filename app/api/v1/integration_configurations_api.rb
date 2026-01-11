# app/api/v1/integration_configurations_api.rb
module V1
  class IntegrationConfigurationsApi < Grape::API
    resource :integrations do
      desc "Listar todas las configuraciones de integraciones" do
        detail "Retorna lista paginada de configuraciones con filtros opcionales"
        success Entities::TenantIntegrationConfigurationSummaryEntity
      end
      params do
        optional :tenant_id, type: Integer, desc: "Filtrar por tenant"
        optional :provider_slug, type: String, desc: "Filtrar por slug del proveedor"
        optional :is_active, type: Boolean, desc: "Filtrar por estado activo/inactivo"
        optional :status, type: String, values: %w[success error], desc: "Filtrar por último estado de sync"
        optional :page, type: Integer, default: 1, desc: "Número de página"
        optional :per_page, type: Integer, default: 50, values: 1..100, desc: "Registros por página"
      end
      get do
        integrations = TenantIntegrationConfiguration
          .includes(:integration_provider, :tenant)

        integrations = integrations.where(tenant_id: params[:tenant_id]) if params[:tenant_id]
        integrations = integrations.where(is_active: params[:is_active]) unless params[:is_active].nil?
        integrations = integrations.where(last_sync_status: params[:status]) if params[:status]

        if params[:provider_slug]
          integrations = integrations
            .joins(:integration_provider)
            .where(integration_providers: { slug: params[:provider_slug] })
        end

        integrations = integrations.order(created_at: :desc)
        total = integrations.count

        integrations = integrations
          .offset((params[:page] - 1) * params[:per_page])
          .limit(params[:per_page])

        {
          configurations: Entities::TenantIntegrationConfigurationSummaryEntity.represent(integrations),
          pagination: {
            current_page: params[:page],
            per_page: params[:per_page],
            total_items: total,
            total_pages: (total.to_f / params[:per_page]).ceil
          }
        }
      end

      desc "Crear nueva configuración de integración" do
        detail "Crea una configuración de integración. Alternativa al endpoint marketplace/setup"
        success Entities::TenantIntegrationConfigurationEntity
      end
      params do
        requires :tenant_id, type: Integer, desc: "ID del tenant"
        requires :integration_provider_id, type: Integer, desc: "ID del proveedor de integración"
        requires :credentials, type: Hash, desc: "Credenciales de autenticación"
        requires :enabled_features, type: Array[String], desc: "Features a habilitar"
        optional :sync_frequency, type: String, values: %w[daily weekly monthly], default: "daily"
        optional :sync_hour, type: Integer, values: 0..23, default: 2
        optional :sync_day_of_week, type: Integer, values: 0..6
        optional :sync_day_of_month, type: String, values: %w[start end]
        optional :sync_config, type: Hash, default: {}
        optional :is_active, type: Boolean, default: false
      end
      post do
        tenant = Tenant.find(params[:tenant_id])
        provider = IntegrationProvider.find(params[:integration_provider_id])

        existing = tenant.tenant_integration_configurations
          .find_by(integration_provider_id: provider.id)

        if existing
          error!({
            error: "duplicate_configuration",
            message: "Ya existe una configuración para este proveedor",
            existing_configuration_id: existing.id
          }, 422)
        end

        config = tenant.tenant_integration_configurations.build(
          integration_provider: provider,
          credentials: params[:credentials],
          enabled_features: params[:enabled_features],
          sync_frequency: params[:sync_frequency],
          sync_hour: params[:sync_hour],
          sync_day_of_week: params[:sync_day_of_week],
          sync_day_of_month: params[:sync_day_of_month],
          sync_config: params[:sync_config],
          is_active: params[:is_active]
        )

        if config.save
          present config,
                  with: Entities::TenantIntegrationConfigurationEntity,
                  include_provider: true,
                  include_tenant: true,
                  include_computed: true
        else
          error!({
            error: "validation_error",
            message: config.errors.full_messages.join(", "),
            details: config.errors.messages
          }, 422)
        end
      rescue ActiveRecord::RecordNotFound => e
        error!({
          error: "not_found",
          message: e.message
        }, 404)
      end

      desc "Obtener opciones disponibles para programación de sincronización" do
        detail "Retorna las opciones válidas para configurar la frecuencia de sincronización"
      end
      get "schedule-options" do
        present OpenStruct.new, with: Entities::SyncScheduleOptionsEntity
      end

      route_param :id do
        before do
          @config = TenantIntegrationConfiguration.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          error!({
            error: "not_found",
            message: "Configuración no encontrada"
          }, 404)
        end

        desc "Obtener detalle completo de una configuración" do
          detail "Retorna información detallada de una configuración específica"
          success Entities::TenantIntegrationConfigurationEntity
        end
        params do
          optional :include_provider, type: Boolean, default: true
          optional :include_tenant, type: Boolean, default: true
          optional :include_features, type: Boolean, default: true
          optional :include_computed, type: Boolean, default: true
        end
        get do
          present @config,
                  with: Entities::TenantIntegrationConfigurationEntity,
                  include_provider: params[:include_provider],
                  include_tenant: params[:include_tenant],
                  include_features: params[:include_features],
                  include_computed: params[:include_computed]
        end

        desc "Actualizar configuración completa" do
          detail "Actualiza múltiples campos de la configuración a la vez"
          success Entities::TenantIntegrationConfigurationEntity
        end
        params do
          optional :credentials, type: Hash
          optional :enabled_features, type: Array[String]
          optional :sync_frequency, type: String, values: %w[daily weekly monthly]
          optional :sync_hour, type: Integer, values: 0..23
          optional :sync_day_of_week, type: Integer, values: 0..6
          optional :sync_day_of_month, type: String, values: %w[start end]
          optional :sync_config, type: Hash
        end
        put do
          result = Integrations::TenantConfigurations::UpdateService.new(
            @config,
            declared(params, include_missing: false)
          ).call

          if result.success?
            present result.data,
                    with: Entities::TenantIntegrationConfigurationEntity,
                    include_computed: true,
                    include_provider: true
          else
            error!({
              error: "validation_error",
              message: result.errors.join(", ")
            }, 422)
          end
        end

        desc "Eliminar configuración de integración" do
          detail "Elimina una configuración. Debe estar inactiva primero."
        end
        delete do
          result = Integrations::TenantConfigurations::DestroyService.new(@config).call

          if result.success?
            { success: true, message: result.message }
          else
            error!({
              error: "deletion_error",
              message: result.errors.join(", ")
            }, 422)
          end
        end

        desc "Actualizar solo las credenciales de autenticación" do
          detail "Actualiza únicamente las credenciales sin tocar otros campos"
          success Entities::TenantIntegrationConfigurationEntity
        end
        params do
          requires :credentials, type: Hash, desc: "Nuevas credenciales de autenticación"
          optional :test_connection_after, type: Boolean, default: false,
                   desc: "Probar conexión después de actualizar"
        end
        put "credentials" do
          was_active = @config.is_active
          @config.update!(is_active: false) if was_active

          if @config.update(credentials: params[:credentials])
            @config.update!(last_sync_status: nil, last_sync_error: nil)

            if params[:test_connection_after]
              test_result = Integrations::TenantConfigurations::TestConnectionService.new(
                @config.integration_provider.id,
                params[:credentials]
              ).call

              unless test_result.success?
                error!({
                  error: "connection_test_failed",
                  message: "Credenciales actualizadas pero el test de conexión falló: #{test_result.errors.join(', ')}",
                  config: Entities::TenantIntegrationConfigurationEntity.represent(
                    @config,
                    include_computed: true
                  )
                }, 422)
              end
            end

            @config.update!(is_active: true) if was_active

            present @config,
                    with: Entities::TenantIntegrationConfigurationEntity,
                    include_computed: true,
                    include_provider: true
          else
            error!({
              error: "validation_error",
              message: @config.errors.full_messages.join(", ")
            }, 422)
          end
        end

        desc "Actualizar features habilitadas" do
          detail "Actualiza qué funcionalidades están habilitadas para sincronizar"
          success Entities::TenantIntegrationConfigurationEntity
        end
        params do
          requires :enabled_features, type: Array[String],
                   desc: "Array de feature keys a habilitar"
        end
        put "features" do
          available_features = @config.integration_provider
            .integration_features
            .active
            .pluck(:feature_key)

          invalid_features = params[:enabled_features] - available_features

          if invalid_features.any?
            error!({
              error: "invalid_features",
              message: "Features no disponibles: #{invalid_features.join(', ')}",
              available_features: available_features
            }, 422)
          end

          if @config.update(enabled_features: params[:enabled_features])
            present @config,
                    with: Entities::TenantIntegrationConfigurationEntity,
                    include_computed: true,
                    include_features: true
          else
            error!({
              error: "validation_error",
              message: @config.errors.full_messages.join(", ")
            }, 422)
          end
        end

        desc "Actualizar configuración de programación" do
          detail "Actualiza cuándo y con qué frecuencia se sincroniza"
          success Entities::TenantIntegrationConfigurationEntity
        end
        params do
          requires :sync_frequency, type: String, values: %w[daily weekly monthly]
          requires :sync_hour, type: Integer, values: 0..23
          optional :sync_day_of_week, type: Integer, values: 0..6,
                   desc: "Día de la semana (0=Domingo, 6=Sábado) - solo para frecuencia semanal"
          optional :sync_day_of_month, type: String, values: %w[start end],
                   desc: "Día del mes (start=primer día, end=último día) - solo para frecuencia mensual"
        end
        put "schedule" do
          update_params = {
            sync_frequency: params[:sync_frequency],
            sync_hour: params[:sync_hour],
            sync_day_of_week: params[:sync_day_of_week],
            sync_day_of_month: params[:sync_day_of_month]
          }

          if @config.update(update_params)
            present @config,
                    with: Entities::TenantIntegrationConfigurationEntity,
                    include_computed: true
          else
            error!({
              error: "validation_error",
              message: @config.errors.full_messages.join(", ")
            }, 422)
          end
        end

        desc "Activar configuración de integración" do
          detail "Activa la configuración para permitir sincronizaciones automáticas"
          success Entities::TenantIntegrationConfigurationEntity
        end
        post "activate" do
          result = Integrations::TenantConfigurations::ActivateService.new(@config).call

          if result.success?
            present result.data,
                    with: Entities::TenantIntegrationConfigurationEntity,
                    include_computed: true
          else
            error!({
              error: "activation_error",
              message: result.errors.join(", ")
            }, 422)
          end
        end

        desc "Desactivar configuración de integración" do
          detail "Desactiva la configuración. No se sincronizará automáticamente."
          success Entities::TenantIntegrationConfigurationEntity
        end
        post "deactivate" do
          result = Integrations::TenantConfigurations::DeactivateService.new(@config).call

          if result.success?
            present result.data,
                    with: Entities::TenantIntegrationConfigurationEntity,
                    include_computed: true
          else
            error!({
              error: "deactivation_error",
              message: result.errors.join(", ")
            }, 422)
          end
        end

        desc "Probar conexión de una configuración existente" do
          detail "Prueba la conexión con las credenciales actuales o con credenciales de prueba"
          success Entities::ConnectionTestResultEntity
        end
        params do
          optional :use_new_credentials, type: Hash,
                   desc: "Probar con credenciales diferentes sin guardarlas (opcional)"
        end
        post "test-connection" do
          credentials_to_test = params[:use_new_credentials] || @config.credentials

          result = Integrations::TenantConfigurations::TestConnectionService.new(
            @config.integration_provider.id,
            credentials_to_test
          ).call

          if result.success?
            present result.data, with: Entities::ConnectionTestResultEntity
          else
            error!({
              error: "connection_failed",
              message: result.errors.join(", ")
            }, 422)
          end
        end

        desc "Upload file for file-based integration" do
          detail "Upload and process Excel file for providers like Solred (synchronous processing)"
          consumes [ "multipart/form-data" ]
          success Entities::FileUploadResponseEntity
        end
        params do
          requires :file, type: File, desc: "Excel file to upload (.xlsx or .xls)", documentation: { param_type: "formData", type: "file" }
          optional :description, type: String, desc: "Optional description of the upload"
        end
        post "files" do
          # Delegar toda la lógica al servicio
          service = Integrations::FileUploadService.new(
            config: @config,
            file: params[:file],
            description: params[:description]
          )

          begin
            result = service.call
            present(result, with: Entities::FileUploadResponseEntity)
          rescue Integrations::FileUploadService::ValidationError => e
            error!({
              error: "validation_error",
              message: e.message
            }, 422)
          rescue => e
            error!({
              error: "processing_failed",
              message: e.message,
              sync_execution_id: service.result.dig(:sync_execution, :id)
            }, 500)
          end
        end
      end
    end
  end
end
