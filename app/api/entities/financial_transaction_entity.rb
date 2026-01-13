# app/api/entities/financial_transaction_entity.rb
module Entities
  class FinancialTransactionEntity < Grape::Entity
    expose :id
    expose :tenant_id
    expose :tenant_integration_configuration_id
    expose :integration_raw_data_id
    expose :provider_slug
    expose :transaction_date
    expose :total_amount
    expose :currency
    expose :quantity
    expose :unit_price
    expose :base_amount
    expose :discount_amount
    expose :product_catalog_id
    expose :product_code
    expose :product_name
    expose :vehicle_plate
    expose :card_number
    expose :location_string
    expose :location_lat
    expose :location_lng
    expose :status
    expose :match_confidence
    expose :discrepancy_flags
    expose :reconciliation_metadata, if: { include_metadata: true }
    expose :provider_metadata, if: { include_metadata: true }
    expose :created_at
    expose :updated_at
    expose :calculated_unit_price, if: { include_computed: true } do |transaction, _options|
      transaction.calculated_unit_price
    end
    expose :description, if: { include_computed: true } do |transaction, _options|
      transaction.description
    end
    expose :has_location, if: { include_computed: true } do |transaction, _options|
      transaction.has_location?
    end
    expose :coordinates, if: { include_computed: true } do |transaction, _options|
      transaction.coordinates
    end
    expose :reconciled, if: { include_computed: true } do |transaction, _options|
      transaction.reconciled?
    end

    expose :is_fuel_transaction, if: { include_computed: true } do |transaction, _options|
      transaction.is_fuel_transaction?
    end
    expose :vehicle_refueling, using: Entities::VehicleRefuelingEntity, if: { include_refueling: true }
    expose :vehicle_electric_charge, using: Entities::VehicleElectricChargeEntity, if: { include_charge: true }
    expose :integration_raw_data, using: Entities::IntegrationRawDataEntity, if: { include_raw_data: true }
    expose :status_badge do |transaction, _options|
      case transaction.status
      when "pending"
        "pending"
      when "matched"
        "matched"
      when "unmatched"
        "unmatched"
      when "ignored"
        "ignored"
      else
        "unknown"
      end
    end
  end
end
