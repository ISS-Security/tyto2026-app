# frozen_string_literal: true

require 'base64'
require 'json'
require 'rbnacl'

module Tyto
  # Encrypts and decrypts arbitrary JSON-serializable values via NaCl
  # SimpleBox (XSalsa20-Poly1305 AEAD with random nonce per-message).
  #
  # Used  as the inner encryption layerunderneath rack-session 2.x's
  # AES-256-GCM cookie encryption -- two authenticated encryption layers.
  #
  # Used for pool/Redis session storage and registration / auth tokens. The
  # single MSG_KEY env var covers both purposes -- sessions and tokens
  # are both "messages" persisted off-process.
  class SecureMessage
    class << self
      attr_reader :key

      def encoded_random_bytes(length)
        bytes = RbNaCl::Random.random_bytes(length)
        Base64.strict_encode64 bytes
      end

      # Generate key for Rake tasks (typically not called at runtime)
      def generate_key
        encoded_random_bytes(RbNaCl::SecretBox.key_bytes)
      end

      # Call setup once to pass in MSG_KEY env var
      def setup(msg_key)
        @key = Base64.strict_decode64(msg_key)
      end

      def encrypt(message)
        raise 'message missing' unless message

        message_json = message.to_json
        simple_box = RbNaCl::SimpleBox.from_secret_key(key)
        ciphertext = simple_box.encrypt(message_json)
        new(Base64.urlsafe_encode64(ciphertext))
      end
    end

    def initialize(ciphertext64)
      @message_secure = ciphertext64
    end

    def to_s
      @message_secure
    end

    def decrypt
      ciphertext = Base64.urlsafe_decode64(@message_secure)
      simple_box = RbNaCl::SimpleBox.from_secret_key(self.class.key)
      message_json = simple_box.decrypt(ciphertext)
      JSON.parse(message_json)
    end
  end
end
