# frozen_string_literal: true

require 'roda'
require 'secure_headers'
require_relative 'app'

module Tyto
  # Browser security headers + CSP for the Tyto Web App
  class App < Roda
    plugin :environments
    plugin :multi_route

    # CSP allowlists for Tyto's pinned CDN assets (all SRI-hashed in views)
    SCRIPT_SRC = %w[https://cdn.jsdelivr.net https://unpkg.com].freeze
    STYLE_SRC = %w[https://bootswatch.com https://cdn.jsdelivr.net
                   https://unpkg.com].freeze
    # OSM map tiles, Leaflet marker icons (resolve relative to its CDN CSS),
    # Google SSO avatars, and Leaflet's inline data: icons
    IMG_SRC = %w[https://tile.openstreetmap.org https://unpkg.com
                 https://*.googleusercontent.com data:].freeze

    ## Uncomment to drop the login session in case of any violation
    # use Rack::Protection, reaction: :drop_session
    use SecureHeaders::Middleware

    SecureHeaders::Configuration.default do |config|
      config.cookies = {
        secure: true,
        httponly: true,
        samesite: {
          lax: true
        }
      }

      config.x_frame_options = 'DENY'
      config.x_content_type_options = 'nosniff'
      config.x_xss_protection = '1'
      config.x_permitted_cross_domain_policies = 'none'
      config.referrer_policy = 'origin-when-cross-origin'

      # NOTE: single-quotes needed around 'self' and 'none' in CSPs
      # rubocop:disable Lint/PercentStringArray
      config.csp = {
        report_only: false,
        preserve_schemes: true,
        default_src: %w['self'],
        child_src: %w['self'],
        connect_src: %w['self'],
        img_src: %w['self'] + IMG_SRC,
        font_src: %w['self'],
        script_src: %w['self'] + SCRIPT_SRC,
        style_src: %w['self'] + STYLE_SRC,
        form_action: %w['self'],
        frame_ancestors: %w['none'],
        object_src: %w['none'],
        report_uri: %w[/security/report_csp_violation]
      }
      # rubocop:enable Lint/PercentStringArray
    end

    route('security') do |routing|
      # POST security/report_csp_violation
      routing.post 'report_csp_violation' do
        App.logger.warn "CSP VIOLATION: #{request.body.read}"
        response.status = 204 # No content - the conventional report-sink reply
        nil
      end
    end
  end
end
