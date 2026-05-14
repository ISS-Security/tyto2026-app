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
          new_account = SecureMessage.new(username_or_token).decrypt
          password = routing.params['password'].to_s
          password_confirm = routing.params['password_confirm'].to_s

          if password.empty? || password != password_confirm
            flash[:error] = 'Passwords did not match'
            routing.redirect "/auth/register/#{username_or_token}"
          end

          CreateAccount.new(App.config).call(
            email: new_account['email'],
            username: new_account['username'],
            password: password
          )
          flash[:notice] = 'Account created -- please log in'
          routing.redirect '/auth/login'
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
            view :account, locals: { account: @current_account.account_info, viewer: @current_account }
          elsif @current_account.admin?
            begin
              response = GetAccount.new(App.config).call(@current_account, username: username)
              target = response.fetch('attributes').merge('include' => response['include'])
              view :account, locals: { account: target, viewer: @current_account }
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
