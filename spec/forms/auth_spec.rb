# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Tyto::Form::LoginCredentials' do
  it 'HAPPY: passes with username + password' do
    result = Tyto::Form::LoginCredentials.call(username: 'alice', password: 'pw')
    _(result.success?).must_equal true
  end

  it 'SAD: missing username' do
    result = Tyto::Form::LoginCredentials.call(username: '', password: 'pw')
    _(result.failure?).must_equal true
  end

  it 'SAD: missing password' do
    result = Tyto::Form::LoginCredentials.call(username: 'alice', password: '')
    _(result.failure?).must_equal true
  end
end

describe 'Tyto::Form::Registration' do
  it 'HAPPY: valid ASCII username + email-with-@' do
    result = Tyto::Form::Registration.call(username: 'alice', email: 'a@example.com')
    _(result.success?).must_equal true
  end

  it 'SAD: username under 4 chars' do
    result = Tyto::Form::Registration.call(username: 'al', email: 'a@example.com')
    _(result.failure?).must_equal true
  end

  it 'SECURITY: rejects unicode confusable usernames (Cyrillic А)' do
    result = Tyto::Form::Registration.call(username: 'Аlice', email: 'a@example.com')
    _(result.failure?).must_equal true
  end

  it 'SAD: email without @' do
    result = Tyto::Form::Registration.call(username: 'alice', email: 'no-at-sign')
    _(result.failure?).must_equal true
  end
end

describe 'Tyto::Form::Passwords' do
  it 'HAPPY: high-entropy matching password' do
    result = Tyto::Form::Passwords.call(
      password: '@3Fs^1HfaF$2', password_confirm: '@3Fs^1HfaF$2'
    )
    _(result.success?).must_equal true
  end

  it 'SAD: low-entropy password rejected (slide-8 example "adf")' do
    result = Tyto::Form::Passwords.call(password: 'adf', password_confirm: 'adf')
    _(result.failure?).must_equal true
    _(result.errors.to_h.keys).must_include :password
  end

  it 'SAD: mismatched confirmation' do
    result = Tyto::Form::Passwords.call(
      password: '@3Fs^1HfaF$2', password_confirm: 'mismatch'
    )
    _(result.failure?).must_equal true
    _(result.errors.to_h.keys).must_include :password_confirm
  end
end
