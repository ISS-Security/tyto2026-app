# frozen_string_literal: true

require 'dry-validation'

module Tyto
  # Shared form-validation helpers and constants. Individual contracts live
  # in sibling files under app/forms/.
  module Form
    # ASCII-only username: rejects unicode confusables (e.g. Cyrillic А).
    USERNAME_REGEX = /\A[a-zA-Z0-9]+([._]?[a-zA-Z0-9]+)*\z/

    # Per slide 12: the simplest possible "looks-like-an-email" check.
    # Correctness is verified via the verification-link round-trip,
    # not a regex.
    EMAIL_REGEX = /@/

    # Minimum Shannon entropy for a password. See slide 8: "adf" ≈ 1.58
    # fails; "@3Fs^1HfaF$2" ≈ 3.41 passes.
    PASSWORD_ENTROPY_MIN = 3.0

    # Flattens dry-validation errors to a single string per field.
    def self.validation_errors(validation)
      validation.errors.to_h.transform_values(&:first)
    end

    # Original (sanitized) input values, for re-rendering the form.
    def self.message_values(validation)
      validation.values.to_h
    end
  end
end
