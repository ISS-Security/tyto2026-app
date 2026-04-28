# frozen_string_literal: true

module Tyto
  # Creates a course via the Tyto API.
  class CreateCourse
    class InvalidInput < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account_id:, name:, description: nil)
      validate!(name: name, description: description)
      @client.authenticated_post(
        '/courses',
        { name: name, description: description },
        current_account_id: current_account_id
      )
    end

    private

    def validate!(name:, description:)
      raise InvalidInput, 'Course name is required' if name.to_s.strip.empty?
      raise InvalidInput, 'Course name must be 200 characters or fewer' if name.length > 200
      raise InvalidInput, 'Description must be 2000 characters or fewer' if description && description.length > 2000
    end
  end
end
