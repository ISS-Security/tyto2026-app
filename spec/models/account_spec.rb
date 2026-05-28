# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Account parser model' do
  def account_info(capabilities: nil, enrollments: [])
    info = {
      'type' => 'account',
      'attributes' => { 'username' => 'alice', 'email' => 'alice@example.com' },
      'include' => { 'enrollments' => enrollments }
    }
    info['capabilities'] = capabilities if capabilities
    info
  end

  describe 'logged_in? / logged_out?' do
    it 'HAPPY: with info + token reports logged in' do
      account = Tyto::Account.from_api(account_info, 'tok')
      _(account.logged_in?).must_equal true
      _(account.logged_out?).must_equal false
    end

    it 'HAPPY: with nils reports logged out' do
      account = Tyto::Account.from_api(nil, nil)
      _(account.logged_in?).must_equal false
      _(account.logged_out?).must_equal true
    end
  end

  describe 'admin? (capabilities-backed)' do
    it 'HAPPY: true when capabilities.is_admin is true' do
      caps = { 'is_admin' => true, 'can_create_course' => true, 'can_manage_system_roles' => true }
      _(Tyto::Account.from_api(account_info(capabilities: caps), 'tok').admin?).must_equal true
    end

    it 'SAD: false when capabilities.is_admin is false' do
      caps = { 'is_admin' => false, 'can_create_course' => false, 'can_manage_system_roles' => false }
      _(Tyto::Account.from_api(account_info(capabilities: caps), 'tok').admin?).must_equal false
    end

    it 'EDGE: false when capabilities key is absent (other-Account envelope)' do
      _(Tyto::Account.from_api(account_info, 'tok').admin?).must_equal false
      _(Tyto::Account.from_api(nil, nil).admin?).must_equal false
    end
  end

  describe 'course_creator? (capabilities-backed)' do
    it 'HAPPY: true when capabilities.can_create_course is true' do
      caps = { 'is_admin' => false, 'can_create_course' => true, 'can_manage_system_roles' => false }
      _(Tyto::Account.from_api(account_info(capabilities: caps), 'tok').course_creator?).must_equal true
    end

    it 'SAD: false when can_create_course is false' do
      caps = { 'is_admin' => false, 'can_create_course' => false, 'can_manage_system_roles' => false }
      _(Tyto::Account.from_api(account_info(capabilities: caps), 'tok').course_creator?).must_equal false
    end

    it 'EDGE: false when capabilities key absent' do
      _(Tyto::Account.from_api(account_info, 'tok').course_creator?).must_equal false
    end
  end

  describe 'avatar (attribute-backed)' do
    it 'HAPPY: returns the avatar URL when present (SSO account)' do
      info = account_info
      info['attributes']['avatar'] = 'https://lh3.googleusercontent.com/a/pic'
      _(Tyto::Account.from_api(info, 'tok').avatar).must_equal 'https://lh3.googleusercontent.com/a/pic'
    end

    it 'EDGE: nil when no avatar attribute (password account)' do
      _(Tyto::Account.from_api(account_info, 'tok').avatar).must_be_nil
    end
  end

  describe 'roles_for_course (enrollments-backed, unchanged)' do
    let(:enrollments) do
      [
        { 'course_id' => 1, 'role' => 'owner' },
        { 'course_id' => 1, 'role' => 'instructor' },
        { 'course_id' => 2, 'role' => 'student' }
      ]
    end

    it 'HAPPY: returns every role the account holds in that course' do
      account = Tyto::Account.from_api(account_info(enrollments: enrollments), 'tok')
      _(account.roles_for_course(1).sort).must_equal %w[instructor owner]
      _(account.roles_for_course(2)).must_equal ['student']
    end

    it 'SAD: empty list for an unknown course' do
      account = Tyto::Account.from_api(account_info(enrollments: enrollments), 'tok')
      _(account.roles_for_course(999)).must_equal []
    end
  end

  describe 'student_in?' do
    let(:enrollments) do
      [
        { 'course_id' => 1, 'role' => 'owner' },
        { 'course_id' => 2, 'role' => 'student' }
      ]
    end

    it 'HAPPY: true for a course the account is a student in' do
      _(Tyto::Account.from_api(account_info(enrollments: enrollments), 'tok').student_in?(2)).must_equal true
    end

    it 'SAD: false for a course where the role is not student' do
      _(Tyto::Account.from_api(account_info(enrollments: enrollments), 'tok').student_in?(1)).must_equal false
    end
  end

  describe 'Account.new is private' do
    it 'SECURITY: cannot bypass the from_api factory' do
      _(-> { Tyto::Account.new({}, 'tok') }).must_raise NoMethodError
    end
  end
end
