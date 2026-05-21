# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module Tyto
  module Form
    COURSE_ROLES = %w[owner instructor staff student].freeze

    EnrollmentByEmail = Dry::Validation.Contract do
      params do
        required(:username).filled(:string)
        required(:role_name).filled(:string, included_in?: Tyto::Form::COURSE_ROLES)
      end
    end
  end
end
