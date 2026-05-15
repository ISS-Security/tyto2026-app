# frozen_string_literal: true

require_relative '../spec_helper'
require 'webmock/minitest'

describe 'VerifyRegistration service' do
  before do
    @registration = { email: 'newperson@example.com', username: 'newperson' }
  end

  after { WebMock.reset! }

  it 'HAPPY: posts the registration + verification_url to the API and returns the data' do
    WebMock.stub_request(:post, "#{API_URL}/auth/register")
           .to_return(status: 202, body: { message: 'Verification email sent' }.to_json,
                      headers: { 'content-type' => 'application/json' })

    result = Tyto::VerifyRegistration.new(app.config).call(**@registration)

    _(result[:email]).must_equal @registration[:email]
    assert_requested(:post, "#{API_URL}/auth/register") do |req|
      body = JSON.parse(req.body)
      body['verification_url'].start_with?("#{app.config.APP_URL}/auth/register/")
    end
  end

  it 'SECURITY: verification_url carries a SecureMessage-encrypted token that decrypts to the registration data' do
    WebMock.stub_request(:post, "#{API_URL}/auth/register").to_return(status: 202)

    decrypted = nil
    WebMock.stub_request(:post, "#{API_URL}/auth/register").to_return(status: 202).with do |req|
      body = JSON.parse(req.body)
      token = body['verification_url'].split('/').last
      decrypted = Tyto::SecureMessage.new(token).decrypt
      true
    end

    Tyto::VerifyRegistration.new(app.config).call(**@registration)

    _(decrypted).wont_be_nil
    _(decrypted['email']).must_equal @registration[:email]
    _(decrypted['username']).must_equal @registration[:username]
  end

  it 'BAD: raises VerificationError on 400 from API' do
    WebMock.stub_request(:post, "#{API_URL}/auth/register")
           .to_return(status: 400, body: { message: 'Email already registered' }.to_json,
                      headers: { 'content-type' => 'application/json' })

    _(proc {
      Tyto::VerifyRegistration.new(app.config).call(**@registration)
    }).must_raise Tyto::VerifyRegistration::VerificationError
  end

  it 'BAD: raises ApiServerError on 500' do
    WebMock.stub_request(:post, "#{API_URL}/auth/register")
           .to_return(status: 500, body: { message: 'boom' }.to_json,
                      headers: { 'content-type' => 'application/json' })

    _(proc {
      Tyto::VerifyRegistration.new(app.config).call(**@registration)
    }).must_raise Tyto::VerifyRegistration::ApiServerError
  end
end
