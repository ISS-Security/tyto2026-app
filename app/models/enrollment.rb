# frozen_string_literal: true

require 'ostruct'

module Tyto
  # Parser model for an Enrollment API envelope. Embeds an Account parser
  # model for the enrolled account so templates can do enrollment.account.username
  # (and, in future, .avatar / .display_name) instead of digging into raw hashes.
  class Enrollment
    attr_reader :id, :account_id, :course_id, :role, :account, :policies

    def self.from_api(envelope)
      new(envelope)
    end

    def initialize(envelope)
      attrs = envelope.fetch('attributes')
      @id = attrs['id']
      @account_id = attrs['account_id']
      @course_id = attrs['course_id']
      @role = attrs['role']
      account_envelope = envelope.dig('include', 'account')
      @account = account_envelope && Account.from_api(account_envelope)
      @policies = OpenStruct.new(envelope['policies'] || {}) # rubocop:disable Style/OpenStructUse
    end

    # Convenience delegate — kept so templates can do `enrollment.username`
    # without dotting through `enrollment.account.username`.
    def username
      @account&.username
    end

    private_class_method :new
  end
end
