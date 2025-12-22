# app/services/integrations/normalizers/retry_normalization_service.rb
module Integrations
  module Normalizers
    class RetryNormalizationService
      def initialize(raw_data, config)
        @raw_data = raw_data
        @config = config
      end

      def call
        unless @raw_data.can_be_normalized?
          return ServiceResult.failure(
            errors: [ "Registro no puede normalizarse (estado: #{@raw_data.processing_status})" ]
          )
        end

        # Obtener normalizer
        normalizer = Factories::NormalizerFactory.build(
          @raw_data.provider_slug,
          @raw_data.feature_key
        )

        # Intentar normalizar
        result = normalizer.normalize(@raw_data, @config)

        if result.success?
          @raw_data.mark_as_normalized!(result.data)
          ServiceResult.success(data: result.data)
        else
          @raw_data.mark_as_failed!(result.errors.join(", "))
          ServiceResult.failure(errors: result.errors)
        end

      rescue StandardError => e
        @raw_data.mark_as_failed!("Error inesperado: #{e.message}")
        ServiceResult.failure(errors: [ e.message ])
      end
    end
  end
end
