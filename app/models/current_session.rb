# frozen_string_literal: true

module Tyto
  # Encapsulates session storage of the authenticated identity:
  # the account-info hash and the API-issued auth_token live as
  # separate SecureMessage-encrypted session keys.
  class CurrentSession
    def initialize(session)
      @secure_session = SecureSession.new(session)
    end

    def current_account
      Account.new(@secure_session.get(:account), @secure_session.get(:auth_token))
    end

    def current_account=(account)
      @secure_session.set(:account, account.account_info)
      @secure_session.set(:auth_token, account.auth_token)
    end

    def delete
      @secure_session.delete(:account)
      @secure_session.delete(:auth_token)
    end
  end
end
