# frozen_string_literal: true

module Tyto
  # Creates a location for a course via the Tyto API.
  class CreateLocationForCourse
    class InvalidInput < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account_id:, course_id:, name:, latitude:, longitude:)
      lat = Float(latitude, exception: false)
      lon = Float(longitude, exception: false)
      validate!(name: name, lat: lat, lon: lon)

      # API encrypts coords via SecureDB.encrypt, which requires a String.
      @client.authenticated_post(
        "/courses/#{course_id}/locations",
        { name: name, latitude: lat.to_s, longitude: lon.to_s },
        current_account_id: current_account_id
      )
    end

    private

    def validate!(name:, lat:, lon:)
      raise InvalidInput, 'Location name is required' if name.to_s.strip.empty?
      raise InvalidInput, 'Location name must be 200 characters or fewer' if name.length > 200
      raise InvalidInput, 'Latitude must be a number between -90 and 90' unless lat&.between?(-90.0, 90.0)
      raise InvalidInput, 'Longitude must be a number between -180 and 180' unless lon&.between?(-180.0, 180.0)
    end
  end
end
