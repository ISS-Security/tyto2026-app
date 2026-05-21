# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Course parser model' do
  let(:envelope) do
    {
      'type' => 'course',
      'attributes' => { 'id' => 7, 'name' => 'SOA', 'description' => 'About things' },
      'policies' => { 'can_view' => true, 'can_edit' => false, 'can_record_attendance' => true },
      'include' => {
        'events' => [
          { 'attributes' => { 'id' => 1, 'name' => 'L1', 'start_at' => '2026-05-21T10:00:00Z',
                              'end_at' => '2026-05-21T12:00:00Z' } }
        ],
        'locations' => [
          { 'attributes' => { 'id' => 2, 'name' => 'Room A', 'latitude' => '24.5', 'longitude' => '121.0' } }
        ],
        'enrollments' => [
          { 'attributes' => { 'id' => 3, 'account_id' => 4, 'course_id' => 7, 'role' => 'student' },
            'include' => { 'account' => { 'type' => 'account', 'attributes' => { 'username' => 'alice' } } } }
        ]
      }
    }
  end

  it 'HAPPY: parses attributes' do
    course = Tyto::Course.from_api(envelope)
    _(course.id).must_equal 7
    _(course.name).must_equal 'SOA'
    _(course.description).must_equal 'About things'
  end

  it 'HAPPY: exposes policies as OpenStruct' do
    course = Tyto::Course.from_api(envelope)
    _(course.policies.can_view).must_equal true
    _(course.policies.can_edit).must_equal false
    _(course.policies.can_record_attendance).must_equal true
  end

  it 'HAPPY: parses nested events, locations, enrollments' do
    course = Tyto::Course.from_api(envelope)
    _(course.events.size).must_equal 1
    _(course.events.first.name).must_equal 'L1'
    _(course.locations.first.name).must_equal 'Room A'
    _(course.enrollments.first.role).must_equal 'student'
    _(course.enrollments.first.username).must_equal 'alice'
  end

  it 'EDGE: empty policies envelope returns hollow OpenStruct (no NoMethodError)' do
    minimal = { 'attributes' => { 'id' => 1, 'name' => 'X' } }
    course = Tyto::Course.from_api(minimal)
    _(course.policies.can_view).must_be_nil
  end

  it 'SAD: missing attributes raises (required key)' do
    _(-> { Tyto::Course.from_api({}) }).must_raise KeyError
  end

  it 'SECURITY: Course.new is private' do
    _(-> { Tyto::Course.new(envelope) }).must_raise NoMethodError
  end
end
