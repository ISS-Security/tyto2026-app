# frozen_string_literal: true

require 'ostruct'

module Tyto
  # Parser model for an Attendance API envelope. Embeds an Account parser
  # model so teaching-staff attendance views can render the student's
  # display info without a second fetch.
  class Attendance
    attr_reader :id, :account_id, :event_id, :course_id, :checked_in_at, :account, :policies

    def self.from_api(envelope)
      new(envelope)
    end

    def initialize(envelope)
      attrs = envelope.fetch('attributes')
      @id = attrs['id']
      @account_id = attrs['account_id']
      @event_id = attrs['event_id']
      @course_id = attrs['course_id']
      @checked_in_at = attrs['checked_in_at']
      account_envelope = envelope.dig('include', 'account')
      @account = account_envelope && Account.from_api(account_envelope)
      @policies = OpenStruct.new(envelope['policies'] || {}) # rubocop:disable Style/OpenStructUse
    end

    private_class_method :new
  end
end
