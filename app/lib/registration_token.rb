# frozen_string_literal: true

module Tyto
  # Wraps the SecureMessage primitive with the registration-flow payload
  # shape ({email, username}) so callers read .email / .username instead
  # of dereferencing a string-keyed hash. No expiration this branch --
  # see PLAN.app.3-auth-token.md Q2 for the reasoning.
  class RegistrationToken
    class InvalidTokenError < StandardError; end

    def self.load(token_string)
      payload = SecureMessage.new(token_string).decrypt
      new(email: payload['email'], username: payload['username'], token: token_string)
    rescue StandardError
      raise InvalidTokenError, 'Invalid or tampered registration token'
    end

    attr_reader :email, :username

    def initialize(email:, username:, token: nil)
      @email = email
      @username = username
      @token = token || SecureMessage.encrypt(email: email, username: username).to_s
    end

    def to_s
      @token
    end
  end
end
