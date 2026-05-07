# frozen_string_literal: true

module Tyto
  # Revokes a system role from an account via the Tyto API.
  class RevokeSystemRole
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account_id:, target_username:, role_name:)
      @client.authenticated_delete(
        "/accounts/#{target_username}/system_roles/#{role_name}",
        current_account_id: current_account_id
      )
    end
  end
end
