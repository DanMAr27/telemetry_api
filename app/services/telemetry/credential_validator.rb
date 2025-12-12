# app/services/telemetry/credential_validator.rb
module Telemetry
  class CredentialValidator
    attr_reader :provider, :credentials, :errors

    def initialize(provider, credentials)
      @provider = provider
      @credentials = credentials.with_indifferent_access
      @errors = []
    end

    def valid?
      validate_required_fields
      validate_field_formats
      errors.empty?
    end

    def self.validate!(provider, credentials)
      validator = new(provider, credentials)
      unless validator.valid?
        raise ValidationError, validator.errors.join(", ")
      end
      true
    end

    private

    def validate_required_fields
      schema_fields.each do |field|
        next unless field[:required]

        field_name = field[:name]
        if credentials[field_name].blank?
          @errors << "#{field[:label]} is required"
        end
      end
    end

    def validate_field_formats
      schema_fields.each do |field|
        field_name = field[:name]
        value = credentials[field_name]

        next if value.blank?

        case field[:type]
        when "email"
          validate_email_format(field, value)
        when "url"
          validate_url_format(field, value)
        when "integer"
          validate_integer_format(field, value)
        end

        # Validaciones adicionales definidas en el schema
        validate_pattern(field, value) if field[:pattern]
        validate_length(field, value) if field[:min_length] || field[:max_length]
      end
    end

    def validate_email_format(field, value)
      unless value.match?(URI::MailTo::EMAIL_REGEXP)
        @errors << "#{field[:label]} must be a valid email"
      end
    end

    def validate_url_format(field, value)
      unless value.match?(URI::DEFAULT_PARSER.make_regexp(%w[http https]))
        @errors << "#{field[:label]} must be a valid URL"
      end
    end

    def validate_integer_format(field, value)
      unless value.to_s.match?(/\A\d+\z/)
        @errors << "#{field[:label]} must be a number"
      end
    end

    def validate_pattern(field, value)
      pattern = Regexp.new(field[:pattern])
      unless value.match?(pattern)
        @errors << "#{field[:label]} format is invalid"
      end
    end

    def validate_length(field, value)
      if field[:min_length] && value.length < field[:min_length]
        @errors << "#{field[:label]} must be at least #{field[:min_length]} characters"
      end

      if field[:max_length] && value.length > field[:max_length]
        @errors << "#{field[:label]} must be at most #{field[:max_length]} characters"
      end
    end

    def schema_fields
      @schema_fields ||= provider.configuration_schema.fetch("fields", [])
    end

    class ValidationError < StandardError; end
  end
end
