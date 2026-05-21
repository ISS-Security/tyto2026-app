# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module Tyto
  module Form
    NewEvent = Dry::Validation.Contract do
      params do
        required(:name).filled(:string, min_size?: 1, max_size?: 200)
        required(:start_at).filled(:string)
        required(:end_at).filled(:string)
        required(:location_id).filled(:integer)
      end

      rule(:start_at, :end_at) do
        start_at = Time.parse(values[:start_at]) rescue nil # rubocop:disable Style/RescueModifier
        end_at = Time.parse(values[:end_at]) rescue nil # rubocop:disable Style/RescueModifier

        if start_at.nil? || end_at.nil?
          key(:start_at).failure('must be a valid datetime') if start_at.nil?
          key(:end_at).failure('must be a valid datetime') if end_at.nil?
        elsif start_at >= end_at
          key(:end_at).failure('must be after start time')
        end
      end
    end
  end
end
