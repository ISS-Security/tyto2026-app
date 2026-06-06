# frozen_string_literal: true

module Tyto
  # Create a new Tyto account by posting to the API.
  class CreateAccount
    class InvalidAccount < StandardError; end

    def initialize(config)
      @client = ApiClient.new(config)
    end

    def call(email:, username:, password:)
      account = { email: email, username: username, password: password }

      @client.post('/accounts', SignedMessage.sign(account))
    rescue ApiClient::ApiError => e
      raise InvalidAccount, e.message
    end
  end
end
