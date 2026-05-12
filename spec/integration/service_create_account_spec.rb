# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

describe 'CreateAccount service' do
  before do
    @new_account = { email: 'new.user@example.com', username: 'new_user', password: 'super_secret' }
  end

  after do
    WebMock.reset!
  end

  it 'HAPPY: posts to /accounts and returns on 201' do
    WebMock.stub_request(:post, "#{API_URL}/accounts")
           .with(body: @new_account.to_json)
           .to_return(status: 201,
                      body: { message: 'Account created', data: { username: 'new_user' } }.to_json,
                      headers: { 'content-type' => 'application/json' })

    result = Tyto::CreateAccount.new(app.config).call(**@new_account)

    _(result).wont_be_nil
    _(result['message']).must_equal 'Account created'
  end

  it 'BAD: raises InvalidAccount on 400 (mass-assignment)' do
    WebMock.stub_request(:post, "#{API_URL}/accounts")
           .with(body: @new_account.to_json)
           .to_return(status: 400,
                      body: { message: 'Illegal Attributes' }.to_json,
                      headers: { 'content-type' => 'application/json' })

    _(proc {
      Tyto::CreateAccount.new(app.config).call(**@new_account)
    }).must_raise Tyto::CreateAccount::InvalidAccount
  end

  it 'BAD: raises InvalidAccount on 500' do
    WebMock.stub_request(:post, "#{API_URL}/accounts")
           .with(body: @new_account.to_json)
           .to_return(status: 500,
                      body: { message: 'boom' }.to_json,
                      headers: { 'content-type' => 'application/json' })

    _(proc {
      Tyto::CreateAccount.new(app.config).call(**@new_account)
    }).must_raise Tyto::CreateAccount::InvalidAccount
  end
end
