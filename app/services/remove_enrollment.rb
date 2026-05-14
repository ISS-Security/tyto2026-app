# frozen_string_literal: true

module Tyto
  # Removes an existing enrollment from a course.
  class RemoveEnrollment
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account, course_id:, enrollment_id:)
      @client.delete(
        "/courses/#{course_id}/enrollments/#{enrollment_id}",
        auth_token: current_account.auth_token
      )
    end
  end
end
