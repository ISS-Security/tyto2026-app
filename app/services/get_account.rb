# frozen_string_literal: true

module Tyto
  # Fetches a single account's full profile (including embedded enrollments).
  class GetAccount
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(username, current_account_id:)
      @client.get("/accounts/#{username}", params: { current_account_id: current_account_id })
    end
  end
end
