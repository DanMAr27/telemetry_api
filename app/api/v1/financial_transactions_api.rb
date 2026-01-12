module V1
  class FinancialTransactionsApi < Grape::API
    resource :financial_transactions do
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
    end
  end
end
