# frozen_string_literal: true

require 'dry-validation'
require_relative 'form_base'

module Tyto
  module Form
    # Login: username + password presence only. Format/strength rules
    # belong to Registration / Passwords; login simply asks "did the
    # user fill both fields?" before forwarding to the API.
    LoginCredentials = Dry::Validation.Contract do
      params do
        required(:username).filled(:string)
        required(:password).filled(:string)
      end
    end

    # Registration: username regex + email shape. We do NOT check
    # password here — that comes on the verification-link form.
    Registration = Dry::Validation.Contract do
      params do
        required(:username).filled(:string, min_size?: 4)
        required(:email).filled(:string)
      end

      rule(:username) do
        key.failure('must contain only ASCII letters, digits, dots, underscores') unless
          USERNAME_REGEX.match?(value)
      end

      rule(:email) do
        key.failure('must contain an @ sign') unless EMAIL_REGEX.match?(value)
      end
    end

    # Passwords: password + password_confirm. The complexity rule is
    # Shannon entropy ≥ PASSWORD_ENTROPY_MIN (slide 8).
    Passwords = Dry::Validation.Contract do
      params do
        required(:password).filled(:string)
        required(:password_confirm).filled(:string)
      end

      rule(:password) do
        entropy = Tyto::StringSecurity.entropy(value)
        if entropy < PASSWORD_ENTROPY_MIN
          key.failure(
            "is too predictable (entropy #{entropy.round(2)} < #{PASSWORD_ENTROPY_MIN})"
          )
        end
      end

      rule(:password_confirm, :password) do
        key.failure('does not match password') if values[:password] != values[:password_confirm]
      end
    end
  end
end
