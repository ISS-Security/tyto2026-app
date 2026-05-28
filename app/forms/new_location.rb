# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module Tyto
  module Form
    NewLocation = Dry::Validation.Contract do
      params do
        required(:name).filled(:string, min_size?: 1, max_size?: 200)
        required(:latitude).filled(:float, included_in?: -90.0..90.0)
        required(:longitude).filled(:float, included_in?: -180.0..180.0)
      end
    end
  end
end
