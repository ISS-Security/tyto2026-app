# frozen_string_literal: true

source 'https://rubygems.org'
ruby File.read('.ruby-version').strip

# Web
gem 'puma', '~>7.0'
gem 'rack-session', '~>2.0'
gem 'roda', '~>3.0'
gem 'slim'

# Configuration
gem 'figaro', '~>1.2'

# Encoding
gem 'base64'

# Communication
gem 'http', '~>5.1'

# Security
gem 'rbnacl', '~>7.1'

# Debugging
gem 'pry'

group :development do
  gem 'bundler-audit'
  gem 'rake'
  gem 'rubocop'
  gem 'rubocop-performance'
end

group :development, :test do
  gem 'rack-test'
  gem 'rerun'
end
