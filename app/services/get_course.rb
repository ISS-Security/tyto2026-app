# frozen_string_literal: true

module Tyto
  # Loads a course detail page in one shot:
  # the course itself + its events + locations + enrollments.
  # Lets the controller hand a single hash to the view.
  class GetCourse
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account, course_id:)
      base = "/courses/#{course_id}"
      auth_token = current_account.auth_token

      {
        'course' => @client.get(base, auth_token: auth_token),
        'events' => @client.get("#{base}/events", auth_token: auth_token).fetch('data', []),
        'locations' => @client.get("#{base}/locations", auth_token: auth_token).fetch('data', []),
        'enrollments' => @client.get("#{base}/enrollments", auth_token: auth_token).fetch('data', [])
      }
    end
  end
end
