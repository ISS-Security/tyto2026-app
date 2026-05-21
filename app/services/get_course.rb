# frozen_string_literal: true

module Tyto
  # Loads a course detail page in one shot:
  # the course itself + its events + locations + enrollments.
  # Returns a Course parser model with nested parser models for each
  # association — templates read `course.name`, `course.policies.can_edit`,
  # etc. instead of digging into raw hashes.
  class GetCourse
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account, course_id:)
      base = "/courses/#{course_id}"
      auth_token = current_account.auth_token
      course_envelope = @client.get(base, auth_token: auth_token)

      events = fetch_list("#{base}/events", auth_token)
      locations = fetch_list("#{base}/locations", auth_token)
      enrollments = fetch_list("#{base}/enrollments", auth_token)

      course_envelope['include'] = {
        'events' => events, 'locations' => locations, 'enrollments' => enrollments
      }
      Course.from_api(course_envelope)
    end

    private

    def fetch_list(path, auth_token)
      @client.get(path, auth_token: auth_token).fetch('data', [])
    end
  end
end
