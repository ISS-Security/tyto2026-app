# frozen_string_literal: true

require 'redis'
require_relative 'secure_message'

module Tyto
  # Wraps a session-like Hash and stores values as SecureMessage
  # ciphertexts. The inner cipher key (MSG_KEY) is owned by
  # SecureMessage; this class only delegates encrypt/decrypt and
  # exposes the Redis URL to the wipe utility.
  class SecureSession
    SESSION_SECRET_BYTES = 64

    class << self
      # Accepts either a URL string (plain `redis://` or local) or a
      # hash already shaped for `Redis.new`/`Rack::Session::Redis`
      # (e.g. `{ url: 'rediss://...', ssl_params: { verify_mode: ... } }`).
      # Stored as a hash so wipe_redis_sessions can pass it through to Redis.new.
      def setup(redis_server)
        @redis_opts = redis_server.is_a?(Hash) ? redis_server : { url: redis_server }
      end

      def generate_secret
        SecureMessage.encoded_random_bytes(SESSION_SECRET_BYTES)
      end

      def wipe_redis_sessions
        redis = Redis.new(**@redis_opts)
        # rubocop:disable Style/HashEachMethods -- Redis#keys returns an Array, not a Hash
        redis.keys.each { |session_id| redis.del session_id }
        # rubocop:enable Style/HashEachMethods
      end
    end

    def initialize(session)
      @session = session
    end

    def set(key, value)
      @session[key] = SecureMessage.encrypt(value).to_s
    end

    def get(key)
      return nil unless @session && @session[key]

      SecureMessage.new(@session[key]).decrypt
    end

    def delete(key)
      @session.delete(key)
    end
  end
end
