# frozen_string_literal: true

module Tyto
  # Revokes a system role from an account via the Tyto API.
  class RevokeSystemRole
    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(current_account, target_username:, role_name:)
      @client.delete(
        "/accounts/#{target_username}/system_roles/#{role_name}",
        auth_token: current_account.auth_token
      )
    end
  end
end
