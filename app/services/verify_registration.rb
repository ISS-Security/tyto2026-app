# frozen_string_literal: true

module Tyto
  # Two-step registration kickoff: encrypts {email, username} into a
  # URL-safe SecureMessage token, attaches the verification URL, and
  # POSTs to the API's /auth/register so the API can dispatch a
  # verification email. The token's encryption proves the user controls
  # the email address before they get to set a password.
  #
  # TODO: registration token has no expiration this branch (see plan Q2).
  # A future cleanup branch can introduce a sibling RegistrationToken lib
  # paralleling the API's AuthToken to add an expiry timestamp.
  class VerifyRegistration
    class VerificationError < StandardError; end
    class ApiServerError < StandardError; end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config)
    end

    def call(email:, username:)
      registration_data = { email: email, username: username }
      verification_token = SecureMessage.encrypt(registration_data).to_s
      verification_url = "#{@config.APP_URL}/auth/register/#{verification_token}"

      @client.post('/auth/register', registration_data.merge(verification_url: verification_url))
      registration_data
    rescue ApiClient::ApiError => e
      raise ApiServerError, e.message if e.status >= 500

      raise VerificationError, e.message
    end
  end
end
