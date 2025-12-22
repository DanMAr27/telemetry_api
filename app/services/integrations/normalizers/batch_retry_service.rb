# app/services/integrations/normalizers/batch_retry_service.rb
module Integrations
  module Normalizers
    class BatchRetryService
      def initialize(raw_data_records, config)
        @records = raw_data_records
        @config = config
      end

      def call
        stats = {
          total: @records.count,
          processed: 0,
          failed: 0,
          errors: []
        }

        @records.each do |raw_data|
          result = RetryNormalizationService.new(raw_data, @config).call

          if result.success?
            stats[:processed] += 1
          else
            stats[:failed] += 1
            stats[:errors] << {
              raw_data_id: raw_data.id,
              external_id: raw_data.external_id,
              error: result.errors.join(", ")
            }
          end
        end

        ServiceResult.success(data: stats)
      rescue StandardError => e
        ServiceResult.failure(errors: [ e.message ])
      end
    end
  end
end
