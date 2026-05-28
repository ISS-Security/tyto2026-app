# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Location parser model' do
  it 'HAPPY: parses attributes from a full envelope' do
    envelope = { 'attributes' => { 'id' => 1, 'name' => 'Room A',
                                   'latitude' => '24.5', 'longitude' => '121.0' },
                 'policies' => { 'can_view' => true } }
    location = Tyto::Location.from_api(envelope)
    _(location.name).must_equal 'Room A'
    _(location.latitude).must_equal '24.5'
    _(location.policies.can_view).must_equal true
  end

  it 'HAPPY: tolerates a bare attributes hash (legacy include shape)' do
    location = Tyto::Location.from_api(
      'id' => 1, 'name' => 'Room A', 'latitude' => '24.5', 'longitude' => '121.0'
    )
    _(location.name).must_equal 'Room A'
  end
end
