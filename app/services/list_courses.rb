# frozen_string_literal: true

module Tyto
  # Lists all courses via the Tyto API.
  class ListCourses
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account)
      @client.get('/courses', auth_token: current_account.auth_token).fetch('data', [])
    end
  end
end
