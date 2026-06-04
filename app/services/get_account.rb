# frozen_string_literal: true

module Tyto
  # Fetches a single account's details from the API. The API wraps the account
  # in an AuthorizedAccount envelope that also carries a freshly-minted
  # READ_ONLY auth token (the shareable "API key"):
  #   { data: { attributes: { account: <envelope>, auth_token: <READ_ONLY> } } }
  # We parse both into an Account model so self- and admin-views share one path.
  class GetAccount
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account, username:)
      response = @client.get("/accounts/#{username}", auth_token: current_account.auth_token)
      attributes = response.fetch('data').fetch('attributes')
      Account.from_api(attributes.fetch('account'), attributes['auth_token'])
    end
  end
end
