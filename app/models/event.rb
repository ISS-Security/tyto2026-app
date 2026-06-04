# frozen_string_literal: true

require 'ostruct'
require 'time'

module Tyto
  # Parser model for an Event API envelope.
  class Event
    attr_reader :id, :name, :start_at, :end_at, :my_attendance_id, :location, :policies,
      :course_id, :course_name

    def self.from_api(envelope)
      new(envelope)
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def initialize(envelope)
      attrs = envelope.fetch('attributes')
      @id = attrs['id']
      @name = attrs['name']
      @start_at = attrs['start_at']
      @end_at = attrs['end_at']
      @my_attendance_id = attrs['my_attendance_id']
      location_hash = envelope.dig('include', 'location')
      @location = location_hash && Location.from_api(location_hash)
      course_hash = envelope.dig('include', 'course')
      if course_hash
        course_attrs = course_hash['attributes'] || course_hash
        @course_id = course_attrs['id']
        @course_name = course_attrs['name']
      end
      @policies = OpenStruct.new(envelope['policies'] || {}) # rubocop:disable Style/OpenStructUse
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    def live_now?
      start_t = parse(start_at)
      end_t = parse(end_at)
      return false unless start_t && end_t

      Time.now.between?(start_t, end_t)
    end

    def attended?
      !my_attendance_id.nil?
    end

    private_class_method :new

    private

    def parse(string)
      return nil unless string

      Time.iso8601(string.to_s)
    rescue ArgumentError
      nil
    end
  end
end
