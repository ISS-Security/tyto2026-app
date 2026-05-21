# frozen_string_literal: true

module Tyto
  # Assigns a system role to an account via the Tyto API.
  class AssignSystemRole
    class InvalidInput < StandardError; end

    VALID_ROLES = %w[admin creator member].freeze

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account, target_username:, role_name:)
      raise InvalidInput, "Role must be one of: #{VALID_ROLES.join(', ')}" unless VALID_ROLES.include?(role_name)

      @client.put(
        "/accounts/#{target_username}/system_roles/#{role_name}",
        {},
        auth_token: current_account.auth_token
      )
    end
  end
end
