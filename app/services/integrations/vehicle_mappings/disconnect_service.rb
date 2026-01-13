module Integrations
  module VehicleMappings
    class DisconnectService
      attr_reader :mapping, :valid_until

      def initialize(mapping, valid_until = nil)
        @mapping = mapping
        @valid_until = valid_until || Time.current
      end

      def call
        # Validations are now in the model (validate_dates_order)
        if @mapping.update(is_active: false, valid_until: @valid_until)
          ServiceResult.success(data: @mapping, message: "Conexión finalizada exitosamente")
        else
          ServiceResult.failure(errors: @mapping.errors.full_messages)
        end
      rescue => e
        Rails.logger.error("Error desconectando mapping #{@mapping.id}: #{e.message}")
        ServiceResult.failure(errors: [ e.message ])
      end
    end
  end
end
