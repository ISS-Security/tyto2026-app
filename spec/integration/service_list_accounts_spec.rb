# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

describe 'ListAccounts service' do
  before do
    @auth_token = 'admin.session.token'
    @api_response = {
      data: [
        { type: 'account',
          attributes: { username: 'soumya.ray', email: 'sray@nthu.edu.tw', avatar: nil },
          include: { system_roles: %w[admin creator], enrollments: [] },
          policies: { can_view: true } },
        { type: 'account',
          attributes: { username: 'li.wei', email: 'li.wei@nthu.edu.tw', avatar: nil },
          include: { system_roles: [], enrollments: [] },
          policies: { can_view: true } }
      ]
    }
  end

  after { WebMock.reset! }

  it 'HAPPY: returns Account models with usernames and system roles' do
    WebMock.stub_request(:get, "#{API_URL}/accounts")
      .with(headers: { 'Authorization' => "Bearer #{@auth_token}" })
      .to_return(status: 200, body: @api_response.to_json,
                 headers: { 'content-type' => 'application/json' })

    accounts = Tyto::ListAccounts.new(app.config).call(auth_token: @auth_token)

    _(accounts.size).must_equal 2
    _(accounts.first.username).must_equal 'soumya.ray'
    _(accounts.first.system_roles).must_equal %w[admin creator]
    _(accounts.last.system_roles).must_equal []
  end

  it 'HAPPY: forwards role and sort as query params' do
    stub = WebMock.stub_request(:get, "#{API_URL}/accounts")
      .with(query: { 'role' => 'none', 'sort' => 'username' })
      .to_return(status: 200, body: { data: [] }.to_json,
                 headers: { 'content-type' => 'application/json' })

    accounts = Tyto::ListAccounts.new(app.config)
      .call(auth_token: @auth_token, role: 'none', sort: 'username')

    assert_requested(stub)
    _(accounts).must_equal []
  end

  it 'HAPPY: omits filter params entirely when not given' do
    stub = WebMock.stub_request(:get, "#{API_URL}/accounts")
      .to_return(status: 200, body: { data: [] }.to_json,
                 headers: { 'content-type' => 'application/json' })

    Tyto::ListAccounts.new(app.config).call(auth_token: @auth_token)

    assert_requested(stub)
  end

  it 'BAD: raises ForbiddenError on 403 (non-admin caller)' do
    WebMock.stub_request(:get, "#{API_URL}/accounts")
      .to_return(status: 403, body: { message: 'Admins only' }.to_json,
                 headers: { 'content-type' => 'application/json' })

    _(proc {
      Tyto::ListAccounts.new(app.config).call(auth_token: @auth_token)
    }).must_raise Tyto::ListAccounts::ForbiddenError
  end
end
