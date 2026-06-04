# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

describe 'GetAccount service' do
  before do
    @current = Tyto::Account.from_api(
      { 'type' => 'account', 'attributes' => { 'username' => 'me' } },
      'full.session.token'
    )
    @account_envelope = {
      type: 'account',
      attributes: { username: 'me', email: 'me@example.com' },
      include: { enrollments: [], system_roles: [] },
      policies: {},
      capabilities: { is_admin: false, can_create_course: true }
    }
    # The account-detail endpoint wraps the account in an AuthorizedAccount
    # envelope carrying a freshly-minted READ_ONLY key.
    @api_response = {
      data: {
        type: 'authorized_account',
        attributes: { account: @account_envelope, auth_token: 'read.only.key' }
      }
    }
  end

  after { WebMock.reset! }

  it 'HAPPY: parses the account and the READ_ONLY token from the envelope' do
    WebMock.stub_request(:get, "#{API_URL}/accounts/me")
           .to_return(status: 200, body: @api_response.to_json,
                      headers: { 'content-type' => 'application/json' })

    account = Tyto::GetAccount.new(app.config).call(@current, username: 'me')

    _(account.username).must_equal 'me'
    _(account.email).must_equal 'me@example.com'
    _(account.auth_token).must_equal 'read.only.key'
    _(account.course_creator?).must_equal true
  end

  it 'HAPPY: forwards the caller full-session token as the Bearer credential' do
    stub = WebMock.stub_request(:get, "#{API_URL}/accounts/me")
                  .with(headers: { 'Authorization' => 'Bearer full.session.token' })
                  .to_return(status: 200, body: @api_response.to_json,
                             headers: { 'content-type' => 'application/json' })

    Tyto::GetAccount.new(app.config).call(@current, username: 'me')
    assert_requested(stub)
  end

  it 'BAD: raises ApiError when the API forbids the view (404)' do
    WebMock.stub_request(:get, "#{API_URL}/accounts/other")
           .to_return(status: 404, body: { message: 'Account not found' }.to_json,
                      headers: { 'content-type' => 'application/json' })

    _(proc { Tyto::GetAccount.new(app.config).call(@current, username: 'other') })
      .must_raise Tyto::ApiClient::ApiError
  end
end
