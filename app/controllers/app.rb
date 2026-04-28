# frozen_string_literal: true

require 'roda'
require 'slim'
require 'slim/include'

module Tyto
  # Base class for the Tyto Web App
  class App < Roda
    plugin :render, engine: 'slim', views: 'app/presentation/views'
    plugin :assets, css: 'style.css', path: 'app/presentation/assets'
    plugin :public, root: 'app/presentation/public'
    plugin :multi_route
    plugin :flash
    plugin :all_verbs

    route do |routing|
      response['Content-Type'] = 'text/html; charset=utf-8'
      @current_account = session[:current_account]

      routing.public
      routing.assets
      routing.multi_route

      # GET /
      routing.root do
        view 'home', locals: { current_account: @current_account }
      end
    end

    private

    def require_login!(routing)
      return if @current_account

      flash[:error] = 'Please log in to continue'
      routing.redirect '/auth/login'
    end

    def roles_for_course(course_id, current_account)
      return [] unless current_account && current_account['include']

      current_account['include']['enrollments']
        .select { |e| e['course_id'] == course_id }
        .map { |e| e['role'] }
    end
  end
end
