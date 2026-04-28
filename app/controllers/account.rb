# frozen_string_literal: true

require 'roda'
require_relative 'app'

module Tyto
  # Web controller for the Tyto Web App
  class App < Roda
    route('account') do |routing|
      require_login!(routing)

      # GET /account/[username]
      routing.get String do |username|
        if @current_account['username'] == username
          view :account, locals: { current_account: @current_account }
        else
          routing.redirect "/account/#{@current_account['username']}"
        end
      end
    end
  end
end
