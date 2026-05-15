# frozen_string_literal: true

module Tyto
  # Two-step registration kickoff: wraps {email, username} in a
  # RegistrationToken, attaches the verification URL, and POSTs to the
  # API's /auth/register so the API can dispatch a verification email.
  # The token's encryption proves the user controls the email address
  # before they get to set a password.
  class VerifyRegistration
    class VerificationError < StandardError; end
    class ApiServerError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config)
    end

    def call(email:, username:)
      registration_token = RegistrationToken.new(email: email, username: username).to_s
      verification_url = "#{@config.APP_URL}/auth/register/#{registration_token}"
      registration_data = { email: email, username: username, verification_url: verification_url }

      @client.post('/auth/register', registration_data)
      registration_data
    rescue ApiClient::ApiError => e
      raise ApiServerError, e.message if e.status >= 500

      raise VerificationError, e.message
    end
  end
end
