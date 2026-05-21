# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Enrollment parser model' do
  it 'HAPPY: parses attributes and nested account.username' do
    envelope = {
      'attributes' => { 'id' => 3, 'account_id' => 4, 'course_id' => 7, 'role' => 'student' },
      'include' => { 'account' => { 'type' => 'account', 'attributes' => { 'username' => 'alice' } } },
      'policies' => { 'can_manage' => false }
    }
    enrollment = Tyto::Enrollment.from_api(envelope)
    _(enrollment.role).must_equal 'student'
    _(enrollment.username).must_equal 'alice'
    _(enrollment.policies.can_manage).must_equal false
  end
end

describe 'Attendance parser model' do
  it 'HAPPY: parses attributes' do
    envelope = {
      'attributes' => { 'id' => 9, 'account_id' => 4, 'event_id' => 5, 'course_id' => 7,
                        'checked_in_at' => '2026-05-21T10:30:00Z' }
    }
    attendance = Tyto::Attendance.from_api(envelope)
    _(attendance.id).must_equal 9
    _(attendance.event_id).must_equal 5
  end
end
