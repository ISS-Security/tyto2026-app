# frozen_string_literal: true

require_relative '../spec_helper'

describe 'SignedMessage' do
  # Snapshot/restore the class-level key: config/environments.rb already
  # ran setup with the test signing key from secrets.yml, and other specs
  # (service WebMock stubs) depend on it surviving this spec file.
  before do
    @saved_key = Tyto::SignedMessage.instance_variable_get(:@signing_key)
    @signing_key = RbNaCl::SigningKey.generate
    Tyto::SignedMessage.setup(Base64.strict_encode64(@signing_key.to_bytes))
  end

  after do
    Tyto::SignedMessage.instance_variable_set(:@signing_key, @saved_key)
  end

  it 'BAD: should raise KeypairError when setup with a bad signing key' do
    _(proc { Tyto::SignedMessage.setup(nil) })
      .must_raise Tyto::SignedMessage::KeypairError
    _(proc { Tyto::SignedMessage.setup('not-a-base64-key!') })
      .must_raise Tyto::SignedMessage::KeypairError
  end

  it 'HAPPY: should sign a message that the verify key can verify' do
    message = { username: 'new_user', email: 'new@example.com' }

    signed = Tyto::SignedMessage.sign(message)

    _(signed[:data]).must_equal message
    signature = Base64.strict_decode64(signed[:signature])
    verified = @signing_key.verify_key.verify(signature, signed[:data].to_json)
    _(verified).must_equal true
  end

  it 'SECURITY: signature should not verify a tampered message' do
    signed = Tyto::SignedMessage.sign({ username: 'new_user' })
    tampered = { username: 'attacker' }.to_json

    signature = Base64.strict_decode64(signed[:signature])
    _(proc { @signing_key.verify_key.verify(signature, tampered) })
      .must_raise RbNaCl::BadSignatureError
  end

  it 'HAPPY: signing should be deterministic (same message, same signature)' do
    # WebMock body stubs rely on this Ed25519 property: specs can
    # pre-compute the exact signed body a service will send.
    message = { username: 'new_user', password: 'pa55w0rd' }

    _(Tyto::SignedMessage.sign(message)).must_equal Tyto::SignedMessage.sign(message)
  end
end
