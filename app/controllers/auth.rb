# frozen_string_literal: true

require 'roda'
require_relative 'app'

module Tyto
  # Web controller for the Tyto Web App
  class App < Roda
    route('auth') do |routing|
      @login_route = '/auth/login'
      @logout_route = '/auth/logout'
      @register_route = '/auth/register'

      routing.is 'login' do
        # GET /auth/login
        routing.get do
          view :login
        end

        # POST /auth/login
        routing.post do
          validation = Tyto::Form::LoginCredentials.call(routing.params)
          if validation.failure?
            flash.now[:error] = Tyto::Form.validation_errors(validation)
            next view(:login)
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
          view :login
        rescue AuthenticateAccount::ApiServerError => e
          App.logger.warn "API server error: #{e.inspect}"
          flash[:error] = 'Our servers are not responding -- please try later'
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
