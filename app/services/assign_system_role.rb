# frozen_string_literal: true

module Tyto
  # Assigns a system role to an account via the Tyto API.
  class AssignSystemRole
    class InvalidInput < StandardError; end

    VALID_ROLES = %w[admin creator member].freeze

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account_id:, target_username:, role_name:)
      raise InvalidInput, "Role must be one of: #{VALID_ROLES.join(', ')}" unless VALID_ROLES.include?(role_name)

      @client.authenticated_put(
        "/accounts/#{target_username}/system_roles/#{role_name}",
        {},
        current_account_id: current_account_id
      )
    end
  end
end
