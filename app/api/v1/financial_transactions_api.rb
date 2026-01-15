module V1
  class FinancialTransactionsApi < Grape::API
    resource :financial_transactions do
      desc "List financial transactions" do
        detail "Returns a paginated list of financial transactions with optional filters"
      end
      params do
        optional :page, type: Integer, default: 1, desc: "Page number"
        optional :per_page, type: Integer, default: 25, desc: "Items per page"
        optional :status, type: Array[String], desc: "Filter by status (pending, matched, unmatched, ignored)"
        optional :start_date, type: Date, desc: "Filter by start date"
        optional :end_date, type: Date, desc: "Filter by end date"
        optional :provider_slug, type: String, desc: "Filter by provider slug"
        optional :vehicle_plate, type: String, desc: "Filter by vehicle plate"
        optional :include_computed, type: Boolean, default: false, desc: "Include computed fields"
        optional :include_metadata, type: Boolean, default: false, desc: "Include metadata fields"
      end
      get do
        transactions = FinancialTransaction.all

        # Apply filters
        transactions = transactions.where(status: params[:status]) if params[:status].present?
        transactions = transactions.between_dates(params[:start_date], params[:end_date]) if params[:start_date].present? && params[:end_date].present?
        transactions = transactions.by_provider(params[:provider_slug]) if params[:provider_slug].present?
        transactions = transactions.by_vehicle(params[:vehicle_plate]) if params[:vehicle_plate].present?

        # Order by most recent
        transactions = transactions.recent

        # Pagination
        page = params[:page] || 1
        per_page = params[:per_page] || 25
        total_count = transactions.count
        paginated_transactions = transactions.offset((page - 1) * per_page).limit(per_page)

        # Response
        {
          data: Entities::FinancialTransactionEntity.represent(
            paginated_transactions,
            include_computed: params[:include_computed],
            include_metadata: params[:include_metadata]
          ),
          meta: {
            current_page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: (total_count.to_f / per_page).ceil
          }
        }
      end

      desc "Get financial transaction details" do
        detail "Returns detailed information about a specific financial transaction"
      end
      params do
        requires :id, type: Integer, desc: "Transaction ID"
        optional :include_computed, type: Boolean, default: true, desc: "Include computed fields"
        optional :include_metadata, type: Boolean, default: true, desc: "Include metadata fields"
        optional :include_refueling, type: Boolean, default: false, desc: "Include related vehicle refueling"
        optional :include_charge, type: Boolean, default: false, desc: "Include related vehicle electric charge"
        optional :include_raw_data, type: Boolean, default: false, desc: "Include raw integration data"
      end
      get ":id" do
        transaction = FinancialTransaction.find_by(id: params[:id])

        if transaction.nil?
          error!({ error: "not_found", message: "Transaction not found" }, 404)
        end

        present transaction, with: Entities::FinancialTransactionEntity,
                include_computed: params[:include_computed],
                include_metadata: params[:include_metadata],
                include_refueling: params[:include_refueling],
                include_charge: params[:include_charge],
                include_raw_data: params[:include_raw_data]
      end

      desc "Reconcile specific transactions manually" do
        detail "Triggers reconciliation for a list of transaction IDs, regardless of their current status"
      end
      params do
        requires :transaction_ids, type: Array[Integer], desc: "List of transaction IDs to reconcile"
      end
      post "reconcile" do
        # 1. Buscar transacciones
        transactions = FinancialTransaction.where(id: params[:transaction_ids])

        if transactions.empty?
          error!({ error: "no_transactions_found", message: "No provided transactions were found" }, 404)
        end

        # 2. Agrupar por configuración
        # (El servicio de conciliación funciona por configuración, así que agrupamos)
        transactions_by_config = transactions.group_by(&:tenant_integration_configuration)

        total_stats = {
          processed: 0,
          matched: 0,
          unmatched: 0,
          ignored: 0
        }

        # 3. Procesar por grupo
        transactions_by_config.each do |config, config_transactions|
          service = Financial::ReconciliationService.new(config, config_transactions)
          result = service.call

          # Acumular stats
          total_stats[:processed] += result[:processed]
          total_stats[:matched] += result[:matched]
          total_stats[:unmatched] += result[:unmatched]
          total_stats[:ignored] += result[:ignored]
        end

        present({
          status: "completed",
          summary: "Processed #{total_stats[:processed]} transactions across #{transactions_by_config.keys.size} configurations",
          reconciliation: total_stats
        })
      end

      desc "Preview deletion impact" do
        detail "Analyzes the impact of deleting a transaction without actually deleting it"
      end
      params do
        requires :id, type: Integer, desc: "Transaction ID"
      end
      post ":id/deletion-preview" do
        transaction = FinancialTransaction.find(params[:id])
        impact = SoftDelete::ImpactAnalyzer.new(transaction).analyze

        {
          transaction_id: params[:id],
          can_delete: impact[:can_delete],
          recommendation: impact[:recommendation],
          blockers: impact[:blockers],
          warnings: impact[:warnings],
          impact: {
            will_cascade: impact[:will_cascade],
            will_nullify: impact[:will_nullify],
            total_affected: impact[:total_affected]
          },
          estimated_time: impact[:estimated_time]
        }
      rescue ActiveRecord::RecordNotFound
        error!({ error: "not_found", message: "Transaction not found" }, 404)
      end

      desc "Soft delete transaction" do
        detail "Soft deletes a transaction with validations and audit trail"
      end
      params do
        requires :id, type: Integer, desc: "Transaction ID"
        optional :force, type: Boolean, default: false, desc: "Force deletion ignoring warnings"
      end
      delete ":id" do
        transaction = FinancialTransaction.find(params[:id])

        coordinator = SoftDelete::DeletionCoordinator.new(
          transaction,
          force: params[:force]
        )

        result = coordinator.call

        if result[:success]
          {
            success: true,
            message: result[:message],
            transaction_id: params[:id],
            impact: {
              cascade_count: result[:cascade_count],
              nullify_count: result[:nullify_count]
            },
            audit_log_id: result[:audit_log]&.id
          }
        else
          error!({
            error: "deletion_failed",
            message: result[:message],
            errors: result[:errors],
            warnings: result[:warnings],
            requires_force: result[:requires_force]
          }, 422)
        end
      rescue ActiveRecord::RecordNotFound
        error!({ error: "not_found", message: "Transaction not found" }, 404)
      end
    end
  end
end
