# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Event parser model' do
  def event_envelope(start_at: '2026-05-21T10:00:00Z', end_at: '2026-05-21T12:00:00Z', # rubocop:disable Metrics/MethodLength
                     my_attendance_id: nil)
    {
      'attributes' => {
        'id' => 1, 'name' => 'Lecture', 'start_at' => start_at, 'end_at' => end_at,
        'my_attendance_id' => my_attendance_id
      },
      'include' => {
        'location' => { 'attributes' => { 'id' => 2, 'name' => 'Room A',
                                          'latitude' => '24.5', 'longitude' => '121.0' } },
        'course' => { 'attributes' => { 'id' => 7, 'name' => 'SOA' } }
      },
      'policies' => { 'can_view' => true, 'can_record_attendance' => false }
    }
  end

  it 'HAPPY: parses attributes + nested location + course' do
    event = Tyto::Event.from_api(event_envelope)
    _(event.name).must_equal 'Lecture'
    _(event.location.name).must_equal 'Room A'
    _(event.course_id).must_equal 7
    _(event.course_name).must_equal 'SOA'
  end

  it 'HAPPY: live_now? true when now is between start and end' do
    now = Time.now
    envelope = event_envelope(
      start_at: (now - 60).iso8601, end_at: (now + 60).iso8601
    )
    _(Tyto::Event.from_api(envelope).live_now?).must_equal true
  end

  it 'SAD: live_now? false for future events' do
    now = Time.now
    envelope = event_envelope(
      start_at: (now + 3600).iso8601, end_at: (now + 7200).iso8601
    )
    _(Tyto::Event.from_api(envelope).live_now?).must_equal false
  end

  it 'HAPPY: attended? true when my_attendance_id present' do
    _(Tyto::Event.from_api(event_envelope(my_attendance_id: 42)).attended?).must_equal true
    _(Tyto::Event.from_api(event_envelope).attended?).must_equal false
  end
end
