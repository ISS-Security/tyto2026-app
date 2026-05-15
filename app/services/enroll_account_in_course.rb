# frozen_string_literal: true

module Tyto
  # Enrolls an existing account in a course in a given role.
  class EnrollAccountInCourse
    class InvalidInput < StandardError; end

    VALID_ROLES = %w[owner instructor staff student].freeze

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account, course_id:, username:, role_name:)
      raise InvalidInput, "Role must be one of: #{VALID_ROLES.join(', ')}" unless VALID_ROLES.include?(role_name)

      @client.post(
        "/courses/#{course_id}/enrollments/#{username}",
        { role_name: role_name },
        auth_token: current_account.auth_token
      )
    end
  end
end
