# app/api/entities/tenant_summary_entity.rb
module Entities
  class TenantSummaryEntity < Grape::Entity
    expose :id
    expose :name
    expose :slug
    expose :email
    expose :status
    expose :created_at
    expose :status_badge do |tenant, _options|
      case tenant.status
      when "active" then "success"
      when "trial" then "info"
      when "suspended" then "warning"
      else "default"
      end
    end
  end
end
