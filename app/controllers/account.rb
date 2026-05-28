# frozen_string_literal: true

require 'roda'
require_relative 'app'

module Tyto
  # Web controller for the Tyto Web App
  class App < Roda
    route('account') do |routing|
      routing.on String do |username_or_token|
        # POST /account/[registration_token]
        # Completes registration by setting a password.
        routing.post do
          token = RegistrationToken.load(username_or_token)

          validation = Tyto::Form::Passwords.call(routing.params)
          if validation.failure?
            flash.now[:error] = Tyto::Form.validation_errors(validation)
            next view(:register_confirm, locals: {
                        registration_token: username_or_token,
                        email: token.email,
                        username: token.username
                      })
          end

          CreateAccount.new(App.config).call(
            email: token.email,
            username: token.username,
            password: validation[:password]
          )
          flash[:notice] = 'Account created -- please log in'
          routing.redirect '/auth/login'
        rescue RegistrationToken::InvalidTokenError
          flash[:error] = 'Verification link is invalid or expired'
          routing.redirect '/auth/register'
        rescue StandardError => e
          App.logger.error "ERROR CREATING ACCOUNT: #{e.inspect}"
          flash[:error] = 'Could not create account'
          routing.redirect '/auth/register'
        end

        require_login!(routing)
        username = username_or_token

        routing.on 'system_roles' do
          routing.on String do |role_name|
            unless @current_account.admin?
              flash[:error] = 'Only admins can manage system roles'
              routing.redirect "/account/#{@current_account.username}"
            end

            # PUT /account/[username]/system_roles/[role_name]
            routing.put do
              AssignSystemRole.new(App.config).call(
                @current_account,
                target_username: username,
                role_name: role_name
              )
              flash[:notice] = "Granted #{role_name} to #{username}"
              routing.redirect "/account/#{username}"
            rescue StandardError => e
              flash[:error] = "Could not grant role: #{e.message}"
              routing.redirect "/account/#{username}"
            end

            # DELETE /account/[username]/system_roles/[role_name]
            routing.delete do
              RevokeSystemRole.new(App.config).call(
                @current_account,
                target_username: username,
                role_name: role_name
              )
              flash[:notice] = "Revoked #{role_name} from #{username}"
              routing.redirect "/account/#{username}"
            rescue StandardError => e
              flash[:error] = "Could not revoke role: #{e.message}"
              routing.redirect "/account/#{username}"
            end
          end
        end

        # GET /account/[username]
        routing.get do
          if @current_account.username == username
            view :account, locals: { account: @current_account, viewer: @current_account }
          elsif @current_account.admin?
            begin
              response = GetAccount.new(App.config).call(@current_account, username: username)
              view :account, locals: { account: Account.from_api(response), viewer: @current_account }
            rescue ApiClient::ApiError => e
              flash[:error] = "Could not load account: #{e.message}"
              routing.redirect "/account/#{@current_account.username}"
            end
          else
            routing.redirect "/account/#{@current_account.username}"
          end
        end
      end
    end
  end
end
