# app/models/integration_auth_schema.rb
class IntegrationAuthSchema < ApplicationRecord
  belongs_to :integration_provider

  validates :auth_fields, presence: true
  validates :integration_provider_id, uniqueness: {
    scope: :is_active,
    conditions: -> { where(is_active: true) },
    message: "ya tiene un schema de autenticación activo"
  }, if: :is_active?
  validate :validate_auth_fields_structure

  # Scopes
  scope :active, -> { where(is_active: true) }

  def field_names
    return [] unless auth_fields.is_a?(Array)
    auth_fields.map { |field| field["name"] }.compact
  end

  def required_fields
    return [] unless auth_fields.is_a?(Array)
    auth_fields.select { |field| field["required"] == true }
  end

  private

  def validate_auth_fields_structure
    return if auth_fields.blank?

    unless auth_fields.is_a?(Array)
      errors.add(:auth_fields, "debe ser un array")
      return
    end

    auth_fields.each_with_index do |field, index|
      unless field.is_a?(Hash)
        errors.add(:auth_fields, "el elemento #{index} debe ser un objeto")
        next
      end

      # Validar campos requeridos
      required_keys = [ "name", "type", "label" ]
      missing_keys = required_keys - field.keys

      if missing_keys.any?
        errors.add(:auth_fields, "el campo #{index} requiere: #{missing_keys.join(', ')}")
      end

      # Validar tipos permitidos
      valid_types = [ "text", "password", "url", "select" ]
      if field["type"].present? && !valid_types.include?(field["type"])
        errors.add(:auth_fields, "tipo '#{field['type']}' no válido en campo #{index}")
      end
    end
  end
end
