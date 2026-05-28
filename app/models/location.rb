# frozen_string_literal: true

require 'ostruct'

module Tyto
  # Parser model for a Location API envelope.
  class Location
    attr_reader :id, :name, :latitude, :longitude, :policies

    def self.from_api(envelope)
      # Permissive: location envelopes sometimes arrive as just the
      # attributes hash (legacy include shape).
      data = envelope.key?('attributes') ? envelope : { 'attributes' => envelope }
      new(data)
    end

    def initialize(envelope)
      attrs = envelope.fetch('attributes')
      @id = attrs['id']
      @name = attrs['name']
      @latitude = attrs['latitude']
      @longitude = attrs['longitude']
      @policies = OpenStruct.new(envelope['policies'] || {}) # rubocop:disable Style/OpenStructUse
    end

    private_class_method :new
  end
end
