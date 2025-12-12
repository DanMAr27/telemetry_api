# app/api/entities/company_entity.rb
module Entities
  class CompanyEntity < Grape::Entity
    expose :id
    expose :name
    expose :tax_id
    expose :email
    expose :phone
    expose :address
    expose :city
    expose :country
    expose :is_active
    expose :created_at
    expose :updated_at

    # Estadísticas opcionales
    expose :stats, if: ->(instance, options) { options[:include_stats] } do
      expose :total_vehicles do |instance|
        instance.vehicles.count
      end

      expose :active_vehicles do |instance|
        instance.vehicles.where(is_active: true).count
      end

      expose :telemetry_credentials_count do |instance|
        instance.telemetry_credentials.count
      end

      expose :active_telemetry_credentials do |instance|
        instance.telemetry_credentials.active.count
      end
    end
  end
end
