# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Tyto::Form::NewLocation' do
  it 'HAPPY: valid name + coords within range' do
    result = Tyto::Form::NewLocation.call(
      name: 'Room A', latitude: '24.5', longitude: '121.0'
    )
    _(result.success?).must_equal true
  end

  it 'SAD: latitude out of range' do
    result = Tyto::Form::NewLocation.call(
      name: 'Room A', latitude: '91.0', longitude: '0'
    )
    _(result.failure?).must_equal true
  end

  it 'SAD: longitude out of range' do
    result = Tyto::Form::NewLocation.call(
      name: 'Room A', latitude: '0', longitude: '181.0'
    )
    _(result.failure?).must_equal true
  end

  it 'SAD: missing name' do
    result = Tyto::Form::NewLocation.call(
      name: '', latitude: '24.5', longitude: '121.0'
    )
    _(result.failure?).must_equal true
  end
end
