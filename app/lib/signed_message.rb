# frozen_string_literal: true

require 'base64'
require 'json'
require 'rbnacl'

module Tyto
  # Signs outgoing API request bodies with the App's private Ed25519
  # SIGNING_KEY so the API (holding only the public VERIFY_KEY) can verify
  # that non-authenticated requests came from this app, untampered.
  class SignedMessage
    class KeypairError < StandardError; end

    # Call setup once to pass in config variable with SIGNING_KEY attribute
    def self.setup(signing_key64)
      @signing_key = Base64.strict_decode64(signing_key64)
    rescue StandardError
      raise KeypairError, 'Signing key not found'
    end

    def self.sign(message)
      signature = RbNaCl::SigningKey.new(@signing_key)
        .sign(message.to_json)
        .then { |sig| Base64.strict_encode64(sig) }

      { data: message, signature: signature }
    end
  end
end
