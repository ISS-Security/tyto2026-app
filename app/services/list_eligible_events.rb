# frozen_string_literal: true

module Tyto
  # Cross-course list of events the caller can currently check in to.
  # Powers the home-page "right now" block.
  class ListEligibleEvents
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account)
      @client
        .get('/attendances/eligible', auth_token: current_account.auth_token)
        .fetch('data', [])
    end
  end
end
