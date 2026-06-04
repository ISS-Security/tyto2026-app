# frozen_string_literal: true

module Tyto
  # Fetches the admin-only accounts index from the API (GET /accounts),
  # forwarding the Members page's role filter / sort params so the App
  # stays a thin renderer (filtering and ordering happen server-side).
  class ListAccounts
    # Raised when the API answers 403 -- the caller is not an admin (or
    # holds a token whose scope cannot read accounts).
    class ForbiddenError < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(auth_token:, role: nil, sort: nil)
      params = { role: role, sort: sort }.compact
      response = @client.get('/accounts', params: params, auth_token: auth_token)
      response['data'].map { |account_info| Account.from_api(account_info) }
    rescue ApiClient::ApiError => e
      raise ForbiddenError, e.message if e.status == 403

      raise
    end
  end
end
