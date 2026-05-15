# frozen_string_literal: true

require 'time'

module Tyto
  # Creates an event for a course via the Tyto API.
  class CreateEventForCourse
    class InvalidInput < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account, course_id:, name:, start_at:, end_at:, location_id:) # rubocop:disable Metrics/ParameterLists
      start_iso = to_iso8601(start_at, 'start_at')
      end_iso = to_iso8601(end_at, 'end_at')
      loc_id = Integer(location_id, exception: false)

      validate!(name: name, start_iso: start_iso, end_iso: end_iso, location_id: loc_id)

      @client.post(
        "/courses/#{course_id}/events",
        { name: name, start_at: start_iso, end_at: end_iso, location_id: loc_id },
        auth_token: current_account.auth_token
      )
    end

    private

    # Browsers send <input type="datetime-local"> as "YYYY-MM-DDTHH:MM";
    # ISO 8601 needs seconds, so append ":00" before parsing.
    def to_iso8601(value, field)
      raw = value.to_s
      raw = "#{raw}:00" if raw.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}\z/)
      Time.iso8601(raw).iso8601
    rescue ArgumentError
      raise InvalidInput, "#{field} must be a valid ISO 8601 timestamp"
    end

    def validate!(name:, start_iso:, end_iso:, location_id:)
      raise InvalidInput, 'Event name is required' if name.to_s.strip.empty?
      raise InvalidInput, 'Event name must be 200 characters or fewer' if name.length > 200
      raise InvalidInput, 'Location is required' if location_id.nil?
      raise InvalidInput, 'start_at must be before end_at' if Time.iso8601(start_iso) >= Time.iso8601(end_iso)
    end
  end
end
