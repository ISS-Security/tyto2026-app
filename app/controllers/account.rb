# frozen_string_literal: true

require 'roda'
require_relative 'app'

module Tyto
  # Web controller for the Tyto Web App
  class App < Roda
    route('account') do |routing|
      require_login!(routing)

      routing.on String do |username|
        routing.on 'system_roles' do
          routing.on String do |role_name|
            unless admin?(@current_account)
              flash[:error] = 'Only admins can manage system roles'
              routing.redirect "/account/#{@current_account['username']}"
            end

            # PUT /account/[username]/system_roles/[role_name]
            routing.put do
              AssignSystemRole.new(App.config).call(
                current_account_id: @current_account['id'],
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
                current_account_id: @current_account['id'],
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
          if @current_account['username'] == username
            view :account, locals: { account: @current_account, viewer: @current_account }
          elsif admin?(@current_account)
            begin
              response = GetAccount.new(App.config).call(username, current_account_id: @current_account['id'])
              target = response.fetch('attributes').merge('include' => response['include'])
              view :account, locals: { account: target, viewer: @current_account }
            rescue ApiClient::ApiError => e
              flash[:error] = "Could not load account: #{e.message}"
              routing.redirect "/account/#{@current_account['username']}"
            end
          else
            routing.redirect "/account/#{@current_account['username']}"
          end
        end
      end
    end
  end
end
