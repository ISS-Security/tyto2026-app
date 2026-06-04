# frozen_string_literal: true

require 'http'
require 'json'

module Tyto
  # Completes "Sign in with Google" (OAuth 2.0 authorization-code flow,
  # Solution 3): the App exchanges the authorization `code` for tokens at
  # Google's token endpoint -- server-side, using the client secret -- then
  # forwards the resulting OIDC `id_token` to the Tyto API's POST /auth/sso.
  # The API verifies the id_token against Google's JWKS and returns a Tyto
  # session token, which the caller stores in the encrypted session.
  #
  # The client secret never leaves the server; the browser only ever sees the
  # one-time `code`.
  class AuthorizeGoogleAccount
    # Raised for any failure in the Google handshake or the API hand-off, so
    # the controller can show one "could not sign in with Google" message.
    class UnauthorizedError < StandardError
      def message = 'Could not sign in with Google'
    end

    def initialize(config)
      @config = config
      @client = ApiClient.new(config)
    end

    # code -> { account: <account hash>, auth_token: <Tyto session token> }
    def call(code)
      id_token = exchange_code_for_id_token(code)
      authorize_with_api(id_token)
    end

    private

    def exchange_code_for_id_token(code)
      response = HTTP.headers(accept: 'application/json')
        .post(@config.GOOGLE_TOKEN_URL, form: token_params(code))
      raise UnauthorizedError unless response.status.success?

      JSON.parse(response.to_s).fetch('id_token')
    rescue KeyError, JSON::ParserError
      raise UnauthorizedError
    end

    def token_params(code)
      {
        client_id: @config.GOOGLE_CLIENT_ID,
        client_secret: @config.GOOGLE_CLIENT_SECRET,
        code: code,
        grant_type: 'authorization_code',
        redirect_uri: @config.GOOGLE_REDIRECT_URI
      }
    end

    def authorize_with_api(id_token)
      response = @client.post('/auth/sso', { id_token: id_token })
      attributes = response.fetch('data').fetch('attributes')
      { account: attributes.fetch('account'), auth_token: attributes['auth_token'] }
    rescue ApiClient::ApiError
      raise UnauthorizedError
    end
  end
end
