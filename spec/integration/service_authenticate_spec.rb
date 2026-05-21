# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

describe 'AuthenticateAccount service' do
  before do
    @credentials = { username: 'soumya.ray', password: 'mypa$$w0rd' }
    @bad_credentials = { username: 'soumya.ray', password: 'wrong_password' }
    @account_envelope = {
      type: 'account',
      attributes: { username: 'soumya.ray', email: 'sray@nthu.edu.tw' },
      include: { enrollments: [], system_roles: [] }
    }
    @api_response = {
      type: 'authenticated_account',
      attributes: {
        account: @account_envelope,
        auth_token: 'opaque.encrypted.bearer'
      }
    }
  end

  after { WebMock.reset! }

  it 'HAPPY: returns account hash and auth_token' do
    WebMock.stub_request(:post, "#{API_URL}/auth/authenticate")
           .with(body: @credentials.to_json)
           .to_return(status: 200,
                      body: @api_response.to_json,
                      headers: { 'content-type' => 'application/json' })

    result = Tyto::AuthenticateAccount.new(app.config).call(**@credentials)

    _(result).wont_be_nil
    _(result[:auth_token]).must_equal 'opaque.encrypted.bearer'
    _(result[:account]['attributes']['username']).must_equal 'soumya.ray'
    _(result[:account]['include']).wont_be_nil
  end

  it 'BAD: raises UnauthorizedError on 403' do
    WebMock.stub_request(:post, "#{API_URL}/auth/authenticate")
           .with(body: @bad_credentials.to_json)
           .to_return(status: 403,
                      body: { message: 'Invalid credentials' }.to_json,
                      headers: { 'content-type' => 'application/json' })

    _(proc {
      Tyto::AuthenticateAccount.new(app.config).call(**@bad_credentials)
    }).must_raise Tyto::AuthenticateAccount::UnauthorizedError
  end

  it 'BAD: raises ApiServerError on 500' do
    WebMock.stub_request(:post, "#{API_URL}/auth/authenticate")
           .with(body: @credentials.to_json)
           .to_return(status: 500,
                      body: { message: 'boom' }.to_json,
                      headers: { 'content-type' => 'application/json' })

    _(proc {
      Tyto::AuthenticateAccount.new(app.config).call(**@credentials)
    }).must_raise Tyto::AuthenticateAccount::ApiServerError
  end
end
