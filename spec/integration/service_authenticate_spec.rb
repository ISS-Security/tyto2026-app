# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

describe 'AuthenticateAccount service' do
  before do
    @credentials = { username: 'soumya.ray', password: 'mypa$$w0rd' }
    @bad_credentials = { username: 'soumya.ray', password: 'wrong_password' }
    @api_response = {
      type: 'account',
      attributes: { id: 1, username: 'soumya.ray', email: 'sray@nthu.edu.tw' },
      include: { enrollments: [], system_roles: [] }
    }
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: returns the authenticated account' do
    WebMock.stub_request(:post, "#{API_URL}/auth/authenticate")
           .with(body: @credentials.to_json)
           .to_return(status: 200,
                      body: @api_response.to_json,
                      headers: { 'content-type' => 'application/json' })

    account = Tyto::AuthenticateAccount.new(app.config).call(**@credentials)

    _(account).wont_be_nil
    _(account['username']).must_equal 'soumya.ray'
    _(account['email']).must_equal 'sray@nthu.edu.tw'
    _(account['include']).wont_be_nil
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
