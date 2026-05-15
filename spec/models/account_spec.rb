# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Account parser model' do
  def account_info(system_roles: [], enrollments: [])
    {
      'type' => 'account',
      'attributes' => { 'username' => 'alice', 'email' => 'alice@example.com' },
      'include' => { 'system_roles' => system_roles, 'enrollments' => enrollments }
    }
  end

  describe 'logged_in? / logged_out?' do
    it 'HAPPY: with info + token reports logged in' do
      account = Tyto::Account.new(account_info, 'tok')
      _(account.logged_in?).must_equal true
      _(account.logged_out?).must_equal false
    end

    it 'HAPPY: with nils reports logged out' do
      account = Tyto::Account.new(nil, nil)
      _(account.logged_in?).must_equal false
      _(account.logged_out?).must_equal true
    end
  end

  describe 'admin?' do
    it 'HAPPY: true when system_roles include admin' do
      _(Tyto::Account.new(account_info(system_roles: %w[admin]), 'tok').admin?).must_equal true
    end

    it 'SAD: false otherwise' do
      _(Tyto::Account.new(account_info(system_roles: %w[creator]), 'tok').admin?).must_equal false
      _(Tyto::Account.new(account_info, 'tok').admin?).must_equal false
      _(Tyto::Account.new(nil, nil).admin?).must_equal false
    end
  end

  describe 'course_creator?' do
    it 'HAPPY: creator system role is a course creator' do
      _(Tyto::Account.new(account_info(system_roles: %w[creator]), 'tok').course_creator?).must_equal true
    end

    it 'HAPPY: admin is also a course creator' do
      _(Tyto::Account.new(account_info(system_roles: %w[admin]), 'tok').course_creator?).must_equal true
    end

    it 'SAD: plain member is not' do
      _(Tyto::Account.new(account_info(system_roles: %w[member]), 'tok').course_creator?).must_equal false
    end
  end

  describe 'roles_for_course' do
    let(:enrollments) do
      [
        { 'course_id' => 1, 'role' => 'owner' },
        { 'course_id' => 1, 'role' => 'instructor' },
        { 'course_id' => 2, 'role' => 'student' }
      ]
    end

    it 'HAPPY: returns every role the account holds in that course' do
      account = Tyto::Account.new(account_info(enrollments: enrollments), 'tok')
      _(account.roles_for_course(1).sort).must_equal %w[instructor owner]
      _(account.roles_for_course(2)).must_equal ['student']
    end

    it 'SAD: empty list for an unknown course' do
      account = Tyto::Account.new(account_info(enrollments: enrollments), 'tok')
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
      _(Tyto::Account.new(account_info(enrollments: enrollments), 'tok').student_in?(2)).must_equal true
    end

    it 'SAD: false for a course where the role is not student' do
      _(Tyto::Account.new(account_info(enrollments: enrollments), 'tok').student_in?(1)).must_equal false
    end
  end
end
