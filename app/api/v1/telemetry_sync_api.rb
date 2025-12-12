# app/api/v1/telemetry_sync_api.rb
module V1
  class TelemetrySyncApi < Grape::API
    version "v1", using: :path
    format :json
    prefix :api

    helpers do
      def current_company
        Company.find(params[:company_id]) if params[:company_id]
      end

      def authorize_company!
        error!("Company not found", 404) unless current_company
      end

      def find_credential!
        credential = current_company.telemetry_credentials.find(params[:credential_id])
        error!("Credential not active", 422) unless credential.is_active?
        credential
      end
    end

    resource :companies do
      route_param :company_id do
        resource :telemetry_credentials do
          route_param :credential_id do
            namespace :sync do
              desc "Sync refuels (fuel fill-ups)",
                   tags: [ "Telemetry Sync" ]
              params do
                optional :from_date, type: DateTime, desc: "Start date for sync"
                optional :to_date, type: DateTime, desc: "End date for sync"
                optional :vehicle_id, type: Integer, desc: "Sync specific vehicle only"
              end
              post :refuels do
                authorize_company!
                credential = find_credential!

                sync_service = Telemetry::SyncService.new(credential)
                result = sync_service.sync_refuels(
                  vehicle_id: params[:vehicle_id],
                  from_date: params[:from_date],
                  to_date: params[:to_date]
                )

                {
                  success: result[:success],
                  sync_log_id: result[:sync_log_id],
                  stats: result[:stats],
                  error: result[:error]
                }
              end

              desc "Sync electric charges",
                   tags: [ "Telemetry Sync" ]
              params do
                optional :from_date, type: DateTime, desc: "Start date for sync"
                optional :to_date, type: DateTime, desc: "End date for sync"
                optional :vehicle_id, type: Integer, desc: "Sync specific vehicle only"
              end
              post :charges do
                authorize_company!
                credential = find_credential!

                sync_service = Telemetry::SyncService.new(credential)
                result = sync_service.sync_charges(
                  vehicle_id: params[:vehicle_id],
                  from_date: params[:from_date],
                  to_date: params[:to_date]
                )

                {
                  success: result[:success],
                  sync_log_id: result[:sync_log_id],
                  stats: result[:stats],
                  error: result[:error]
                }
              end

              desc "Sync all data types",
                   tags: [ "Telemetry Sync" ]
              params do
                optional :from_date, type: DateTime, desc: "Start date for sync"
                optional :to_date, type: DateTime, desc: "End date for sync"
              end
              post :all do
                authorize_company!
                credential = find_credential!

                sync_service = Telemetry::SyncService.new(credential)
                results = sync_service.sync_all(
                  from_date: params[:from_date],
                  to_date: params[:to_date]
                )

                {
                  success: true,
                  results: results
                }
              end

              desc "Get sync logs",
                   success: Entities::TelemetrySyncLogEntity,
                   is_array: true,
                   tags: [ "Telemetry Sync" ]
              params do
                optional :sync_type, type: String, desc: "Filter by sync type"
                optional :status, type: String, desc: "Filter by status"
                optional :page, type: Integer, default: 1
                optional :per_page, type: Integer, default: 20
              end
              get :logs do
                authorize_company!
                credential = find_credential!

                logs = credential.telemetry_sync_logs.recent
                logs = logs.for_sync_type(params[:sync_type]) if params[:sync_type]
                logs = logs.where(status: params[:status]) if params[:status]

                logs = logs.page(params[:page]).per(params[:per_page])

                present logs, with: Entities::TelemetrySyncLogEntity
              end

              desc "Get specific sync log details",
                   success: Entities::TelemetrySyncLogEntity,
                   tags: [ "Telemetry Sync" ]
              params do
                requires :log_id, type: Integer, desc: "Sync log ID"
              end
              get "logs/:log_id" do
                authorize_company!
                credential = find_credential!

                log = credential.telemetry_sync_logs.find(params[:log_id])
                present log, with: Entities::TelemetrySyncLogEntity,
                        include_errors: true,
                        admin_view: true
              end
            end
          end
        end
      end
    end
  end
end
