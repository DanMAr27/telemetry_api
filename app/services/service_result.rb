# app/services/service_result.rb
class ServiceResult
  attr_reader :data, :errors, :message

  def initialize(success:, data: nil, errors: [], message: nil)
    @success = success
    @data = data
    @errors = errors
    @message = message
  end

  def success?
    @success
  end

  def failure?
    !@success
  end

  def self.success(data: nil, message: nil)
    new(success: true, data: data, message: message)
  end

  def self.failure(errors: [], data: nil, message: nil)
    new(success: false, errors: errors, data: data, message: message)
  end
end
