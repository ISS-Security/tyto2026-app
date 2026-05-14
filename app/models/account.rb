# frozen_string_literal: true

module Tyto
  # Identity parser model: wraps the (account_info hash, auth_token string)
  # pair the API issues at login, and exposes username/email/role predicates
  # as object methods instead of raw-hash lookups.
  #
  # Predicates here keep the week-10 string-array-intersect logic verbatim;
  # only the placement moves off `App` onto a real model. Implementations
  # swap to policy-summary reads in a later refactor branch.
  class Account
    attr_reader :account_info, :auth_token

    def initialize(account_info, auth_token)
      @account_info = account_info
      @auth_token = auth_token
    end

    def logged_in?
      !@account_info.nil? && !@auth_token.nil?
    end

    def logged_out?
      !logged_in?
    end

    def id
      attributes&.dig('id')
    end

    def username
      attributes&.dig('username')
    end

    def email
      attributes&.dig('email')
    end

    def admin?
      system_roles.include?('admin')
    end

    def course_creator?
      system_roles.intersect?(%w[creator admin])
    end

    # An account can hold multiple roles in the same course (e.g.,
    # owner + instructor), so this returns an array of role names.
    def roles_for_course(course_id)
      enrollments.select { |e| e['course_id'] == course_id }.map { |e| e['role'] }
    end

    def student_in?(course_id)
      enrollments.any? { |e| e['course_id'] == course_id && e['role'] == 'student' }
    end

    private

    def attributes
      @account_info && @account_info['attributes']
    end

    def system_roles
      @account_info&.dig('include', 'system_roles') || []
    end

    def enrollments
      @account_info&.dig('include', 'enrollments') || []
    end
  end
end
