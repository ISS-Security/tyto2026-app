# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

describe 'AuthorizeGoogleAccount service' do
  before do
    @code = 'google-auth-code'
    @token_url = app.config.GOOGLE_TOKEN_URL
    @account_envelope = {
      type: 'account',
      attributes: { username: 'sso-user', email: 'sso-user@example.com',
                    avatar: 'https://lh3.googleusercontent.com/a/sso-user' },
      include: { enrollments: [], system_roles: ['member'] },
      capabilities: { is_admin: false, can_create_course: false }
    }
    @api_response = {
      data: {
        type: 'authorized_account',
        attributes: { account: @account_envelope, auth_token: 'tyto.session.token' }
      }
    }
  end

  after { WebMock.reset! }

  it 'HAPPY: exchanges the code for an id_token, then trades it for a Tyto token' do
    google = WebMock.stub_request(:post, @token_url)
      .to_return(status: 200, body: { id_token: 'signed.jwt' }.to_json,
                 headers: { 'content-type' => 'application/json' })
    api = WebMock.stub_request(:post, "#{API_URL}/auth/sso")
      .with(body: Tyto::SignedMessage.sign({ id_token: 'signed.jwt' }).to_json)
      .to_return(status: 200, body: @api_response.to_json,
                 headers: { 'content-type' => 'application/json' })

    result = Tyto::AuthorizeGoogleAccount.new(app.config).call(@code)

    assert_requested(google)
    assert_requested(api)
    _(result[:auth_token]).must_equal 'tyto.session.token'
    _(result[:account]['attributes']['username']).must_equal 'sso-user'
    _(result[:account]['attributes']['avatar']).must_equal 'https://lh3.googleusercontent.com/a/sso-user'
  end

  it 'BAD: raises UnauthorizedError when Google rejects the code' do
    WebMock.stub_request(:post, @token_url)
      .to_return(status: 400, body: { error: 'invalid_grant' }.to_json,
                 headers: { 'content-type' => 'application/json' })

    _(proc { Tyto::AuthorizeGoogleAccount.new(app.config).call(@code) })
      .must_raise Tyto::AuthorizeGoogleAccount::UnauthorizedError
  end

  it 'BAD: raises UnauthorizedError when the API rejects the id_token' do
    WebMock.stub_request(:post, @token_url)
      .to_return(status: 200, body: { id_token: 'signed.jwt' }.to_json,
                 headers: { 'content-type' => 'application/json' })
    WebMock.stub_request(:post, "#{API_URL}/auth/sso")
      .to_return(status: 401, body: { message: 'Invalid SSO credentials' }.to_json,
                 headers: { 'content-type' => 'application/json' })

    _(proc { Tyto::AuthorizeGoogleAccount.new(app.config).call(@code) })
      .must_raise Tyto::AuthorizeGoogleAccount::UnauthorizedError
  end
end
