# frozen_string_literal: true

require_relative '../spec_helper'

describe 'RegistrationToken' do
  describe 'round-trip' do
    it 'HAPPY: new(...).to_s produces a string that load parses back' do
      token = Tyto::RegistrationToken.new(email: 'alice@example.com', username: 'alice')
      wire = token.to_s

      _(wire).must_be_kind_of String

      parsed = Tyto::RegistrationToken.load(wire)
      _(parsed.email).must_equal 'alice@example.com'
      _(parsed.username).must_equal 'alice'
    end
  end

  describe 'tampered / invalid input' do
    it 'BAD: garbage string raises InvalidTokenError' do
      _ { Tyto::RegistrationToken.load('not-a-real-token') }
        .must_raise Tyto::RegistrationToken::InvalidTokenError
    end
  end
end
