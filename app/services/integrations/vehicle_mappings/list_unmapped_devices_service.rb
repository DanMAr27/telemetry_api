module Integrations
  module VehicleMappings
    class ListUnmappedDevicesService
      def initialize(tenant, provider_slug = nil, days_lookback = 30)
        @tenant = tenant
        @provider_slug = provider_slug
        @days_lookback = days_lookback
      end

      def call
        # 1. Get all known external IDs from Raw Data (recently seen)
        raw_devices = fetch_raw_devices

        # 2. Get currently ACTIVE mapped external IDs for this tenant
        mapped_ids = fetch_active_mapped_ids

        # 3. Filter out already mapped
        unmapped = raw_devices.reject { |device| mapped_ids.include?(device[:external_id]) }

        ServiceResult.success(data: unmapped)
      rescue => e
        Rails.logger.error("Error listing unmapped devices: #{e.message}")
        ServiceResult.failure(errors: [ e.message ])
      end

      private

      def fetch_raw_devices
        scope = IntegrationRawData
          .joins(:tenant_integration_configuration)
          .where(tenant_integration_configurations: { tenant_id: @tenant.id })
          .where("integration_raw_data.created_at >= ?", @days_lookback.days.ago)

        scope = scope.where(provider_slug: @provider_slug) if @provider_slug.present?

        # Select distinct IDs to minimize data transfer
        # We also want the latest 'raw_data' to extract the name if possible.
        # Postgres 'DISTINCT ON' is perfect here.

        scope
          .select("DISTINCT ON (external_id) id, external_id, raw_data, provider_slug, created_at")
          .order("external_id, created_at DESC")
          .map do |record|
            {
              external_id: record.external_id,
              name: extract_name(record),
              provider_slug: record.provider_slug,
              last_seen_at: record.created_at
            }
          end
      end

      def fetch_active_mapped_ids
        scope = VehicleProviderMapping
          .joins(:tenant_integration_configuration)
          .where(tenant_integration_configurations: { tenant_id: @tenant.id })
          .active

        if @provider_slug.present?
          scope = scope.joins(tenant_integration_configuration: :integration_provider)
                       .where(integration_providers: { slug: @provider_slug })
        end

        scope.pluck(:external_vehicle_id).uniq
      end

      def extract_name(record)
        # Try common patterns for device name in JSON
        data = record.raw_data
        return nil unless data.is_a?(Hash)

        data["name"] ||
        data["deviceName"] ||
        data.dig("device", "name") ||
        "#{record.provider_slug.humanize} Device #{record.external_id}"
      end
    end
  end
end
