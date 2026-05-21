# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Tyto::Form::EnrollmentByEmail' do
  it 'HAPPY: valid username + course role' do
    %w[owner instructor staff student].each do |role|
      result = Tyto::Form::EnrollmentByEmail.call(username: 'alice', role_name: role)
      _(result.success?).must_equal true
    end
  end

  it 'SAD: system role not allowed' do
    result = Tyto::Form::EnrollmentByEmail.call(username: 'alice', role_name: 'admin')
    _(result.failure?).must_equal true
  end

  it 'SAD: missing username' do
    _(Tyto::Form::EnrollmentByEmail.call(username: '', role_name: 'student').failure?).must_equal true
  end
end
