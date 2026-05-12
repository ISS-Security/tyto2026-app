# frozen_string_literal: true

require 'roda'
require 'figaro'
require 'logger'
require 'openssl'
require 'rack/session'
require 'rack/session/redis'
require_relative '../require_app'

require_app('lib')

module Tyto
  # Configuration for the Tyto Web App
  class App < Roda
    plugin :environments

    # Environment variables setup
    Figaro.application = Figaro::Application.new(
      environment: environment,
      path: File.expand_path('config/secrets.yml')
    )
    Figaro.load
    def self.config = Figaro.env

    # HTTP Request logging
    configure :development, :production do
      plugin :common_logger, $stdout
    end

    # Custom events logging
    LOGGER = Logger.new($stderr)
    def self.logger = LOGGER

    # Session configuration
    ONE_MONTH = 30 * 24 * 60 * 60

    # Redis URL: support both add-on flavors. Redis Cloud (free tier)
    # exposes REDISCLOUD_URL; Heroku Redis (paid) exposes REDIS_URL.
    # Read whichever is set; check Redis Cloud first because it matches
    # the slide-deck convention.
    @redis_url = ENV.delete('REDISCLOUD_URL') || ENV.delete('REDIS_URL')

    # Heroku Redis (and most managed Redis providers) uses self-signed
    # certificates for `rediss://` -- the TLS is there for confidentiality
    # over the provider's private network, not server authentication. The
    # Ruby Redis client verifies certs by default, so we set
    # verify_mode: VERIFY_NONE to keep the encryption while skipping the
    # CA-chain check. Encrypted-but-unauthenticated Redis is acceptable
    # because the traffic stays on the Heroku private network and never
    # crosses the public internet. Plain `redis://` URLs (e.g. local dev)
    # don't go through TLS at all, so no ssl_params are passed.
    @redis_server =
      if @redis_url&.start_with?('rediss://')
        { url: @redis_url, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
      else
        @redis_url
      end

    SecureMessage.setup(ENV.delete('MSG_KEY'))
    SecureSession.setup(@redis_server) # used by `rake session:wipe`

    configure :development, :test do
      # Suppresses log info/warning outputs in dev/test environments
      logger.level = Logger::ERROR

      # Previous approach (rack-session 2.x AES-256-GCM cookie only --
      # superseded by the Pool/Redis split below):
      # use Rack::Session::Cookie,
      #     expire_after: ONE_MONTH, secret: config.SESSION_SECRET

      use Rack::Session::Pool,
          expire_after: ONE_MONTH

      # Uncomment to test the production Redis path locally
      # (requires `brew services start redis` or equivalent):
      # use Rack::Session::Redis,
      #     expire_after: ONE_MONTH,
      #     redis_server: @redis_url

      # Allows binding.pry to be used in development
      require 'pry'

      # Allows running reload! in pry to restart entire app
      def self.reload!
        exec 'pry -r ./spec/test_load_all'
      end
    end

    configure :production do
      # Roda native HTTPS enforcement. `redirect_http_to_https` issues
      # a 301 for HTTP requests; `hsts` adds the Strict-Transport-Security
      # response header so subsequent visits go straight to HTTPS without a
      # round-trip.
      plugin :redirect_http_to_https
      plugin :hsts

      use Rack::Session::Redis,
          expire_after: ONE_MONTH,
          redis_server: @redis_server
    end
  end
end
