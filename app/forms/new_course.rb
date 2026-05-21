# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module Tyto
  module Form
    NewCourse = Dry::Validation.Contract do
      params do
        required(:name).filled(:string, min_size?: 1, max_size?: 200)
        optional(:description).maybe(:string, max_size?: 2000)
      end
    end
  end
end
