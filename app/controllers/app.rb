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
    plugin :assets, css: 'style.css', path: 'app/presentation/assets'
    plugin :public, root: 'app/presentation/public'
    plugin :multi_route
    plugin :flash
    plugin :all_verbs

    route do |routing|
      routing.redirect_http_to_https if App.environment == :production

      response['Content-Type'] = 'text/html; charset=utf-8'
      @current_account = SecureSession.new(session).get(:current_account)

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

    # Raw-hash helper. Will be replaced by an Account predicate when
    # App-side parser models land in 4-validation alongside 7-policies.
    def admin?(current_account)
      system_roles_of(current_account).include?('admin')
    end

    def course_creator?(current_account)
      system_roles_of(current_account).intersect?(%w[creator admin])
    end

    def system_roles_of(current_account)
      current_account&.dig('include', 'system_roles') || []
    end
  end
end
