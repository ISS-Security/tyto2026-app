# frozen_string_literal: true

module Tyto
  # Removes an existing enrollment from a course.
  class RemoveEnrollment
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account_id:, course_id:, enrollment_id:)
      @client.authenticated_delete(
        "/courses/#{course_id}/enrollments/#{enrollment_id}",
        current_account_id: current_account_id
      )
    end
  end
end
