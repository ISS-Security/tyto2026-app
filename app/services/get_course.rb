# frozen_string_literal: true

module Tyto
  # Loads a course detail page in one shot:
  # the course itself + its events + locations + enrollments.
  # Lets the controller hand a single hash to the view.
  class GetCourse
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(course_id, current_account_id:)
      base = "/courses/#{course_id}"
      params = { current_account_id: current_account_id }

      {
        'course' => @client.get(base, params: params),
        'events' => @client.get("#{base}/events", params: params).fetch('data', []),
        'locations' => @client.get("#{base}/locations", params: params).fetch('data', []),
        'enrollments' => @client.get("#{base}/enrollments", params: params).fetch('data', [])
      }
    end
  end
end
