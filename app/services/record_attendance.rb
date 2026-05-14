# frozen_string_literal: true

module Tyto
  # Records a check-in for the calling account at an event.
  class RecordAttendance
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account, course_id:, event_id:)
      @client.post(
        "/courses/#{course_id}/attendances",
        { event_id: event_id },
        auth_token: current_account.auth_token
      )
    end
  end
end
