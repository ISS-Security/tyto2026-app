# frozen_string_literal: true

module Tyto
  # Lists all courses via the Tyto API.
  class ListCourses
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account_id:)
      @client.get('/courses', params: { current_account_id: current_account_id }).fetch('data', [])
    end
  end
end
