# frozen_string_literal: true

module Tyto
  # Identity parser model: wraps the (account_info hash, auth_token string)
  # pair the API issues at login, and exposes username/email/role predicates
  # as object methods instead of raw-hash lookups.
  #
  # Three-way predicate split:
  #   - `admin?` / `course_creator?` are actor-scoped — they read from
  #     the API's `capabilities` envelope key (only present on the
  #     self-Account response).
  #   - `student_in?(course_id)` and `roles_for_course(course_id)` are
  #     per-course — they read from `include.enrollments`.
  #   - Entity predicates ("can I edit this course?") don't live on
  #     Account at all — they live on the matching resource parser model
  #     and read from the resource's `policies` key.
  class Account
    attr_reader :account_info, :auth_token

    def self.from_api(account_info, auth_token = nil)
      new(account_info, auth_token)
    end

    def initialize(account_info, auth_token)
      @account_info = account_info
      @auth_token = auth_token
    end

    private_class_method :new

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
      capabilities['is_admin'] || false
    end

    def course_creator?
      capabilities['can_create_course'] || false
    end

    def roles_for_course(course_id)
      enrollments.select { |e| e['course_id'] == course_id }.map { |e| e['role'] }
    end

    def student_in?(course_id)
      enrollments.any? { |e| e['course_id'] == course_id && e['role'] == 'student' }
    end

    # System-role names for this account (e.g. %w[admin creator]).
    # The view/admin-management template reads this; predicate checks
    # (`admin?`, `course_creator?`) go through capabilities instead.
    def system_roles
      @account_info&.dig('include', 'system_roles') || []
    end

    # Course-enrollment summaries: array of {course_id, course_name, role}
    # hashes. Exposed for the account-detail template; per-course predicates
    # (`student_in?`, `roles_for_course`) prefer the methods above.
    def enrollments
      @account_info&.dig('include', 'enrollments') || []
    end

    private

    def attributes
      @account_info && @account_info['attributes']
    end

    def capabilities
      @account_info&.dig('capabilities') || {}
    end
  end
end
