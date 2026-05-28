# frozen_string_literal: true

module Tyto
  # Lists all courses the current account can see.
  # Returns an array of Course parser models (each carries the slim
  # #index_summary policies block from the API).
  class ListCourses
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account)
      response = @client.get('/courses', auth_token: current_account.auth_token)
      response.fetch('data', []).map { |envelope| Course.from_api(envelope) }
    end
  end
end
