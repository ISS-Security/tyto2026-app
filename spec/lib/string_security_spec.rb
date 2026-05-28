# frozen_string_literal: true

require_relative '../spec_helper'

describe 'StringSecurity.entropy' do
  it 'HAPPY: empty/nil strings have zero entropy' do
    _(Tyto::StringSecurity.entropy('')).must_equal 0.0
    _(Tyto::StringSecurity.entropy(nil)).must_equal 0.0
  end

  it 'HAPPY: matches slide-8 reference values within 0.05' do
    # Slide 8: "adf" ≈ 1.58, "@3Fs^1HfaF$2" ≈ 3.41
    _(Tyto::StringSecurity.entropy('adf')).must_be_close_to 1.58, 0.05
    _(Tyto::StringSecurity.entropy('@3Fs^1HfaF$2')).must_be_close_to 3.41, 0.05
  end

  it 'SAD: long-but-uniform strings have low entropy' do
    _(Tyto::StringSecurity.entropy('aaaaaaaa')).must_equal 0.0
    _(Tyto::StringSecurity.entropy('abababab')).must_be :<, 1.5
  end
end
