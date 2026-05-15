# frozen_string_literal: true

module Tyto
  # Authenticate user credentials against the Tyto API.
  # Returns { account: <account_info hash>, auth_token: <opaque string> }
  # for the caller to wrap into an Account model.
  class AuthenticateAccount
    class UnauthorizedError < StandardError; end
    class ApiServerError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    # rubocop:disable Metrics/MethodLength
    def call(username:, password:)
      validate_credentials!(username, password)

      response = @client.post('/auth/authenticate', { username: username, password: password })
      attributes = response.fetch('attributes')
      {
        account: attributes.fetch('account'),
        auth_token: attributes.fetch('auth_token')
      }
    rescue ApiClient::ApiError => e
      raise UnauthorizedError, "Authentication failed: #{e.message}" if e.status == 403
      raise ApiServerError, e.message if e.status >= 500

      raise
    end
    # rubocop:enable Metrics/MethodLength

    private

    def validate_credentials!(username, password)
      return unless username.to_s.strip.empty? || password.to_s.empty?

      raise UnauthorizedError, 'Username and password required'
    end
  end
end
