# app/api/v1/tenants.rb
module V1
  class TenantsApi < Grape::API
    helpers do
      # Helper para autenticación admin (ajustar según tu sistema)
      def require_admin!
        # Implementar lógica de autenticación admin
        # error!({ error: "unauthorized" }, 401) unless current_user&.admin?
      end
    end

    resource :tenants do
      desc "Listar todos los tenants (clientes)"
      params do
        optional :status, type: String, values: %w[active suspended trial], desc: "Filtrar por estado"
        optional :search, type: String, desc: "Buscar por nombre o email"
        optional :page, type: Integer, default: 1
        optional :per_page, type: Integer, default: 50, values: 1..100
        optional :include_integrations, type: Boolean, default: false
        optional :include_counts, type: Boolean, default: true
      end
      get do
        # require_admin! # Descomentar para requerir permisos admin

        tenants = Tenant.all

        # Filtros
        tenants = tenants.where(status: params[:status]) if params[:status]

        if params[:search].present?
          search_term = "%#{params[:search]}%"
          tenants = tenants.where(
            "name ILIKE :term OR email ILIKE :term OR slug ILIKE :term",
            term: search_term
          )
        end

        # Ordenar
        tenants = tenants.order(created_at: :desc)

        # Paginación
        total = tenants.count
        tenants = tenants.offset((params[:page] - 1) * params[:per_page])
                        .limit(params[:per_page])

        # Presentar
        {
          tenants: Entities::TenantEntity.represent(
            tenants,
            include_integrations: params[:include_integrations],
            include_counts: params[:include_counts],
            include_computed: true
          ),
          pagination: {
            current_page: params[:page],
            per_page: params[:per_page],
            total_items: total,
            total_pages: (total.to_f / params[:per_page]).ceil
          }
        }
      end
      desc "Obtener detalle de un tenant"
      params do
        requires :id, type: Integer, desc: "ID del tenant"
        optional :include_integrations, type: Boolean, default: true
        optional :include_statistics, type: Boolean, default: true
      end
      get ":id" do
        tenant = Tenant.find(params[:id])

        entity_options = {
          include_integrations: params[:include_integrations],
          include_counts: true,
          include_computed: true
        }

        result = Entities::TenantEntity.represent(tenant, entity_options).as_json

        # Agregar estadísticas si se solicitan
        if params[:include_statistics]
          result[:statistics] = {
            total_vehicles: tenant.vehicles.count,
            active_vehicles: tenant.vehicles.active.count,
            total_refuelings: VehicleRefueling.by_tenant(tenant.id).count,
            total_charges: VehicleElectricCharge.by_tenant(tenant.id).count,
            last_sync: tenant.tenant_integration_configurations.active.maximum(:last_sync_at)
          }
        end

        result
      end
      desc "Crear nuevo tenant (cliente)"
      params do
        requires :name, type: String, desc: "Nombre del tenant"
        requires :email, type: String, desc: "Email de contacto"
        optional :slug, type: String, desc: "Slug único (se genera automáticamente si no se proporciona)"
        optional :status, type: String, values: %w[active suspended trial], default: "trial"
        optional :settings, type: Hash, default: {}, desc: "Configuración personalizada"
      end
      post do
        # require_admin!

        tenant = Tenant.new(declared(params, include_missing: false))

        if tenant.save
          present tenant,
                  with: Entities::TenantEntity,
                  include_computed: true
        else
          error!({
            error: "validation_error",
            message: tenant.errors.full_messages.join(", "),
            details: tenant.errors.messages
          }, 422)
        end
      end
      desc "Actualizar tenant"
      params do
        requires :id, type: Integer
        optional :name, type: String
        optional :email, type: String
        optional :status, type: String, values: %w[active suspended trial]
        optional :settings, type: Hash
      end
      put ":id" do
        # require_admin!

        tenant = Tenant.find(params[:id])

        if tenant.update(declared(params, include_missing: false))
          present tenant,
                  with: Entities::TenantEntity,
                  include_computed: true
        else
          error!({
            error: "validation_error",
            message: tenant.errors.full_messages.join(", ")
          }, 422)
        end
      end
      desc "Eliminar tenant"
      params do
        requires :id, type: Integer
        optional :force, type: Boolean, default: false, desc: "Forzar eliminación incluso con datos"
      end
      delete ":id" do
        # require_admin!

        tenant = Tenant.find(params[:id])

        # Verificar si tiene datos asociados
        if !params[:force] && tenant.has_associated_data?
          error!({
            error: "tenant_has_data",
            message: "El tenant tiene datos asociados. Use force=true para eliminar de todas formas.",
            data: {
              vehicles_count: tenant.vehicles.count,
              configurations_count: tenant.tenant_integration_configurations.count,
              refuelings_count: VehicleRefueling.by_tenant(tenant.id).count,
              charges_count: VehicleElectricCharge.by_tenant(tenant.id).count
            }
          }, 422)
        end

        if tenant.destroy
          { success: true, message: "Tenant eliminado exitosamente" }
        else
          error!({
            error: "deletion_error",
            message: tenant.errors.full_messages.join(", ")
          }, 422)
        end
      end
      desc "Activar tenant"
      params do
        requires :id, type: Integer
      end
      post ":id/activate" do
        # require_admin!

        tenant = Tenant.find(params[:id])
        tenant.update!(status: "active")

        present tenant,
                with: Entities::TenantEntity,
                include_computed: true
      end
      desc "Suspender tenant"
      params do
        requires :id, type: Integer
      end
      post ":id/suspend" do
        # require_admin!

        tenant = Tenant.find(params[:id])
        tenant.update!(status: "suspended")

        # Desactivar todas sus integraciones
        tenant.tenant_integration_configurations.active.update_all(is_active: false)

        present tenant,
                with: Entities::TenantEntity,
                include_computed: true
      end
      desc "Obtener estadísticas detalladas del tenant"
      params do
        requires :id, type: Integer
        optional :from_date, type: Date, desc: "Fecha desde"
        optional :to_date, type: Date, desc: "Fecha hasta"
      end
      get ":id/statistics" do
        tenant = Tenant.find(params[:id])

        from_date = params[:from_date] || 30.days.ago
        to_date = params[:to_date] || Date.current

        {
          tenant_id: tenant.id,
          tenant_name: tenant.name,
          period: {
            from: from_date,
            to: to_date
          },
          vehicles: {
            total: tenant.vehicles.count,
            active: tenant.vehicles.active.count,
            with_telemetry: tenant.vehicles_with_telemetry.count
          },
          integrations: {
            total: tenant.tenant_integration_configurations.count,
            active: tenant.tenant_integration_configurations.active.count,
            by_provider: tenant.tenant_integration_configurations
              .joins(:integration_provider)
              .group("integration_providers.name")
              .count
          },
          refuelings: {
            total: VehicleRefueling.by_tenant(tenant.id)
              .between_dates(from_date, to_date).count,
            total_liters: VehicleRefueling.by_tenant(tenant.id)
              .between_dates(from_date, to_date)
              .sum(:volume_liters).to_f.round(2),
            total_cost: VehicleRefueling.by_tenant(tenant.id)
              .between_dates(from_date, to_date)
              .sum(:cost).to_f.round(2)
          },
          electric_charges: {
            total: VehicleElectricCharge.by_tenant(tenant.id)
              .between_dates(from_date, to_date).count,
            total_kwh: VehicleElectricCharge.by_tenant(tenant.id)
              .between_dates(from_date, to_date)
              .sum(:energy_consumed_kwh).to_f.round(2)
          },
          syncs: {
            total_executions: IntegrationSyncExecution
              .joins(:tenant_integration_configuration)
              .where(tenant_integration_configurations: { tenant_id: tenant.id })
              .where("started_at BETWEEN ? AND ?", from_date, to_date)
              .count,
            successful: IntegrationSyncExecution
              .joins(:tenant_integration_configuration)
              .where(tenant_integration_configurations: { tenant_id: tenant.id })
              .where("started_at BETWEEN ? AND ?", from_date, to_date)
              .completed.count
          }
        }
      end
      desc "Estadísticas globales de todos los tenants"
      get "stats" do
        # require_admin!

        {
          total_tenants: Tenant.count,
          by_status: Tenant.group(:status).count,
          active_tenants: Tenant.active.count,
          total_vehicles: Vehicle.count,
          total_integrations: TenantIntegrationConfiguration.count,
          active_integrations: TenantIntegrationConfiguration.active.count,
          total_refuelings: VehicleRefueling.count,
          total_charges: VehicleElectricCharge.count,
          most_active_tenants: Tenant
            .joins(:tenant_integration_configurations)
            .group("tenants.id", "tenants.name")
            .select("tenants.id, tenants.name, COUNT(tenant_integration_configurations.id) as integrations_count")
            .order("integrations_count DESC")
            .limit(10)
            .map { |t| { id: t.id, name: t.name, integrations_count: t.integrations_count } }
        }
      end
    end
  end
end
