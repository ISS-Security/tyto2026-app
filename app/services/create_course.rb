# frozen_string_literal: true

module Tyto
  # Creates a course via the Tyto API.
  class CreateCourse
    class InvalidInput < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account, name:, description: nil)
      validate!(name: name, description: description)
      @client.post(
        '/courses',
        { name: name, description: description },
        auth_token: current_account.auth_token
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
