# app/services/financial/vehicle_mapping_service.rb
module Financial
  class VehicleMappingService
    # Estrategia en cascada para identificar vehículo
    def self.find_vehicle(financial_transaction)
      tenant = financial_transaction.tenant
      provider = financial_transaction.tenant_integration_configuration.integration_provider

      # CASCADA 1: Intentar por matrícula
      if financial_transaction.vehicle_plate.present?
        vehicle = find_by_plate(
          financial_transaction.vehicle_plate,
          tenant.id
        )
        return vehicle if vehicle
      end

      # CASCADA 2: Intentar por tarjeta
      if financial_transaction.card_number.present?
        vehicle = find_by_card(
          financial_transaction.card_number,
          tenant.id,
          provider.id
        )
        return vehicle if vehicle
      end

      # CASCADA 3: No encontrado
      nil
    end

    # Buscar por matrícula con normalización
    def self.find_by_plate(plate, tenant_id)
      normalized_plate = normalize_plate(plate)

      Vehicle
        .where(tenant_id: tenant_id)
        .where("UPPER(REPLACE(license_plate, ' ', '')) = ?", normalized_plate)
        .first
    end

    # Buscar por tarjeta en mappings
    def self.find_by_card(card_number, tenant_id, provider_id)
      mapping = CardVehicleMapping.find_by_card(
        tenant_id,
        provider_id,
        card_number
      )

      mapping&.vehicle
    end

    # Normalizar matrícula (quitar espacios, mayúsculas)
    def self.normalize_plate(plate)
      return nil if plate.blank?
      plate.to_s.gsub(/\s+/, "").upcase
    end

    # Crear mapeo manual (para API)
    def self.create_card_mapping(tenant_id, provider_id, card_number, vehicle_id, alternate_plate: nil)
      CardVehicleMapping.create!(
        tenant_id: tenant_id,
        integration_provider_id: provider_id,
        vehicle_id: vehicle_id,
        card_number: CardVehicleMapping.normalize_card_number_value(card_number),
        alternate_plate: alternate_plate,
        is_active: true
      )
    end
  end
end
