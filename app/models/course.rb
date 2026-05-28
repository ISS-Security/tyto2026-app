# frozen_string_literal: true

require 'ostruct'

module Tyto
  # Parser model that wraps a Course API envelope.
  # Use Course.from_api(envelope_hash) — `new` is private so the named
  # factory is the only entry point and the parsing role stays explicit.
  class Course
    attr_reader :id, :name, :description, :policies, :events, :locations, :enrollments

    def self.from_api(envelope)
      new(envelope)
    end

    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    def initialize(envelope)
      attrs = envelope.fetch('attributes')
      @id = attrs['id']
      @name = attrs['name']
      @description = attrs['description']
      @policies = OpenStruct.new(envelope['policies'] || {}) # rubocop:disable Style/OpenStructUse
      @events = (envelope.dig('include', 'events') || []).map { |e| Event.from_api(e) }
      @locations = (envelope.dig('include', 'locations') || []).map { |l| Location.from_api(l) }
      @enrollments = (envelope.dig('include', 'enrollments') || []).map { |e| Enrollment.from_api(e) }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

    private_class_method :new
  end
end
