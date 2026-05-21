# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Tyto::Form::NewEvent' do
  let(:valid_params) do
    {
      name: 'Lecture 1',
      start_at: '2026-05-21T10:00:00',
      end_at: '2026-05-21T12:00:00',
      location_id: '1'
    }
  end

  it 'HAPPY: well-formed event' do
    _(Tyto::Form::NewEvent.call(valid_params).success?).must_equal true
  end

  it 'SAD: end_at before start_at' do
    bad = valid_params.merge(end_at: '2026-05-21T08:00:00')
    result = Tyto::Form::NewEvent.call(bad)
    _(result.failure?).must_equal true
    _(result.errors.to_h.keys).must_include :end_at
  end

  it 'SAD: missing location_id' do
    bad = valid_params.merge(location_id: '')
    _(Tyto::Form::NewEvent.call(bad).failure?).must_equal true
  end

  it 'SAD: unparseable datetime' do
    bad = valid_params.merge(start_at: 'not-a-date')
    _(Tyto::Form::NewEvent.call(bad).failure?).must_equal true
  end
end
