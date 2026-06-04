# frozen_string_literal: true

require 'rack/method_override'
require 'roda'
require 'slim'
require 'slim/include'

module Tyto
  # Base class for the Tyto Web App
  class App < Roda
    use Rack::MethodOverride

    plugin :render, engine: 'slim', views: 'app/presentation/views'
    # JS is served as asset files from 'self' (the CSP blocks inline scripts);
    # the :maps group loads only on pages that set @load_maps (layout.slim).
    plugin :assets, path: 'app/presentation/assets',
                    css: 'style.css',
                    js: {
                      checkin: ['checkin_geolocate.js'],
                      maps: ['maps_loader.js', 'attendance_map.js', 'location_form.js']
                    }
    plugin :public, root: 'app/presentation/public'
    plugin :multi_route
    plugin :flash
    plugin :all_verbs

    route do |routing|
      routing.redirect_http_to_https if App.environment == :production

      response['Content-Type'] = 'text/html; charset=utf-8'
      @current_account = CurrentSession.new(session).current_account

      routing.public
      routing.assets
      routing.multi_route

      # GET /
      routing.root do
        eligible_events =
          if @current_account.logged_in?
            ListEligibleEvents.new(App.config).call(@current_account)
          else
            []
          end

        view 'home', locals: {
          current_account: @current_account,
          eligible_events: eligible_events
        }
      rescue StandardError => e
        App.logger.warn "Eligible-events lookup failed: #{e.message}"
        view 'home', locals: {
          current_account: @current_account,
          eligible_events: []
        }
      end
    end

    private

    # Exposes the current request's params to view templates so re-rendered
    # forms (Q3: render-in-place on validation failure) can repopulate fields
    # with `value=(params['key'] || '')`.
    def params
      request.params
    end

    def require_login!(routing)
      return if @current_account.logged_in?

      flash[:error] = 'Please log in to continue'
      routing.redirect '/auth/login'
    end
  end
end
