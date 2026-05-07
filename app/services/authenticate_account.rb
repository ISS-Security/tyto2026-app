# frozen_string_literal: true

module Tyto
  # Authenticate user credentials against the Tyto API.
  # Returns the account attributes hash with embedded enrollments.
  class AuthenticateAccount
    class UnauthorizedError < StandardError; end
    class ApiServerError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(username:, password:)
      validate_credentials!(username, password)

      response = @client.post('/auth/authenticate', { username: username, password: password })
      response.fetch('attributes').merge('include' => response['include'])
    rescue ApiClient::ApiError => e
      raise UnauthorizedError, "Authentication failed: #{e.message}" if e.status == 403
      raise ApiServerError, e.message if e.status >= 500

      raise
    end

    private

    def validate_credentials!(username, password)
      return unless username.to_s.strip.empty? || password.to_s.empty?

      raise UnauthorizedError, 'Username and password required'
    end
  end
end
