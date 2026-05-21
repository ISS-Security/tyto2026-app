# frozen_string_literal: true

module Tyto
  # Fetches a single account's full profile (including embedded enrollments).
  class GetAccount
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account, username:)
      @client.get("/accounts/#{username}", auth_token: current_account.auth_token)
    end
  end
end
