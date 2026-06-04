# frozen_string_literal: true

require 'roda'
require_relative 'app'

module Tyto
  # Web controller for the Tyto Web App
  class App < Roda
    route('admin') do |routing|
      require_login!(routing)

      routing.on 'accounts' do
        # GET /admin/accounts
        # Members page: read-only index of every account with system-role
        # badges; rows pivot into the existing /account/[username]
        # management surface. Filter/sort run server-side on the API
        # (?role= and ?sort= are forwarded verbatim).
        routing.get do
          unless @current_account.admin?
            flash[:error] = 'Only admins can view the members list'
            routing.redirect '/'
          end

          role_filter = routing.params['role']
          sort = routing.params['sort']
          accounts = ListAccounts.new(App.config).call(
            auth_token: @current_account.auth_token,
            role: role_filter,
            sort: sort
          )

          view 'admin/accounts/index', locals: {
            accounts: accounts, role_filter: role_filter, sort: sort
          }
        rescue ListAccounts::ForbiddenError
          flash[:error] = 'Only admins can view the members list'
          routing.redirect '/'
        rescue ApiClient::ApiError, StandardError => e
          App.logger.error "MEMBERS PAGE ERROR: #{e.inspect}"
          flash[:error] = 'Could not load the members list'
          routing.redirect '/'
        end
      end
    end
  end
end
