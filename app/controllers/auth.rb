# frozen_string_literal: true

require 'roda'
require 'uri'
require 'securerandom'
require_relative 'app'

module Tyto
  # Web controller for the Tyto Web App
  class App < Roda # rubocop:disable Metrics/ClassLength
    # Build the Google OAuth 2.0 authorization-code URL. `state` is an
    # anti-CSRF nonce echoed back to /auth/sso_callback and verified there.
    def google_oauth_url(config, state)
      query = URI.encode_www_form(
        client_id: config.GOOGLE_CLIENT_ID,
        redirect_uri: config.GOOGLE_REDIRECT_URI,
        response_type: 'code',
        scope: config.GOOGLE_SCOPE,
        state: state
      )
      "#{config.GOOGLE_OAUTH_URL}?#{query}"
    end

    # Mint (once per session) + stash the CSRF state, returning the authorize
    # URL for the "Sign in with Google" button on every login render.
    def sso_login_url(session)
      state = (session['sso_state'] ||= SecureRandom.hex(16))
      google_oauth_url(App.config, state)
    end

    route('auth') do |routing|
      @login_route = '/auth/login'
      @logout_route = '/auth/logout'
      @register_route = '/auth/register'

      routing.is 'login' do
        # GET /auth/login
        routing.get do
          view :login, locals: { google_oauth_url: sso_login_url(session) }
        end

        # POST /auth/login
        routing.post do
          validation = Tyto::Form::LoginCredentials.call(routing.params)
          if validation.failure?
            flash.now[:error] = Tyto::Form.validation_errors(validation)
            next view(:login, locals: { google_oauth_url: sso_login_url(session) })
          end

          authed = AuthenticateAccount.new(App.config).call(
            username: validation[:username], password: validation[:password]
          )
          account = Account.from_api(authed[:account], authed[:auth_token])

          CurrentSession.new(session).current_account = account
          flash[:notice] = "Welcome back #{account.username}!"
          routing.redirect '/'
        rescue AuthenticateAccount::UnauthorizedError
          flash.now[:error] = { credentials: 'Username and password did not match our records' }
          response.status = 401
          view :login, locals: { google_oauth_url: sso_login_url(session) }
        rescue AuthenticateAccount::ApiServerError => e
          App.logger.warn "API server error: #{e.inspect}"
          flash[:error] = 'Our servers are not responding -- please try later'
          routing.redirect @login_route
        end
      end

      routing.is 'sso_callback' do
        # GET /auth/sso_callback?code=...&state=...
        routing.get do
          expected = session.delete('sso_state')
          unless expected && routing.params['state'] == expected
            flash[:error] = 'Sign-in session expired or could not be verified -- please try again'
            routing.redirect @login_route
          end

          authorized = AuthorizeGoogleAccount.new(App.config).call(routing.params['code'])
          account = Account.from_api(authorized[:account], authorized[:auth_token])

          CurrentSession.new(session).current_account = account
          flash[:notice] = "Welcome #{account.username}!"
          routing.redirect '/'
        rescue AuthorizeGoogleAccount::UnauthorizedError
          flash[:error] = 'Could not sign in with Google'
          response.status = 403
          routing.redirect @login_route
        rescue StandardError => e
          App.logger.error "SSO LOGIN ERROR: #{e.inspect}"
          flash[:error] = 'Unexpected error during Google sign-in'
          response.status = 500
          routing.redirect @login_route
        end
      end

      routing.on 'logout' do
        # GET /auth/logout
        routing.get do
          CurrentSession.new(session).delete
          flash[:notice] = "You've been logged out"
          routing.redirect @login_route
        end
      end

      routing.on 'register' do
        # GET /auth/register/[registration_token]
        # Decrypts token; shows the password-entry form.
        routing.is String do |registration_token|
          token = RegistrationToken.load(registration_token)
          view :register_confirm, locals: {
            registration_token: registration_token,
            email: token.email,
            username: token.username
          }
        rescue RegistrationToken::InvalidTokenError
          flash[:error] = 'Verification link is invalid or expired'
          routing.redirect @register_route
        end

        routing.is do
          # GET /auth/register
          routing.get do
            view :register
          end

          # POST /auth/register
          routing.post do
            validation = Tyto::Form::Registration.call(routing.params)
            if validation.failure?
              flash.now[:error] = Tyto::Form.validation_errors(validation)
              next view(:register)
            end

            VerifyRegistration.new(App.config).call(
              email: validation[:email], username: validation[:username]
            )
            flash[:notice] = 'Check your email for a verification link'
            routing.redirect '/'
          rescue VerifyRegistration::VerificationError => e
            flash.now[:error] = { registration: e.message }
            view :register
          rescue VerifyRegistration::ApiServerError => e
            App.logger.warn "API server error: #{e.inspect}"
            flash[:error] = 'Our servers are not responding -- please try later'
            routing.redirect @register_route
          rescue StandardError => e
            App.logger.error "ERROR REGISTERING: #{e.inspect}"
            flash[:error] = 'Could not start registration'
            routing.redirect @register_route
          end
        end
      end
    end
  end
end
