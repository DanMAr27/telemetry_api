# config/application.rb

require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "sprockets/railtie"
require "active_storage/engine"
require "action_mailer/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module VehiclesApi
  class Application < Rails::Application
    # ... (Configuraciones por defecto) ...

    # Rutas personalizadas para carga automática (Autoload Paths)

    # Asegura que app/services sea cargado
    services_path = Rails.root.join("app/services")
    config.autoload_paths << services_path
    config.eager_load_paths << services_path

    # ✅ CORRECCIÓN: Asegura que app/api y sus subdirectorios (como v1) sean cargados.
    api_path = Rails.root.join("app/api")
    config.autoload_paths << api_path
    config.eager_load_paths << api_path # Para entornos de producción/eager loading

    config.api_only = true
  end
end
