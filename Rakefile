# frozen_string_literal: true

require './require_app'

task :print_env do
  puts "Environment: #{ENV['RACK_ENV'] || 'development'}"
end

desc 'Run application console (pry)'
task console: [:print_env] do
  sh 'pry -r ./spec/test_load_all'
end

desc 'Run rubocop to check style'
task :style do
  sh 'rubocop .'
end

namespace :run do
  desc 'Run Web App in development mode'
  task dev: [:print_env] do
    sh 'puma -p 9292'
  end
end

namespace :generate do
  desc 'Create cookie secret'
  task :session_secret do
    require 'rbnacl'
    require 'base64'
    puts "New SESSION_SECRET (base64): #{Base64.urlsafe_encode64(RbNaCl::Random.random_bytes(64))}"
  end
end

namespace :url do
  # usage: $ rake url:integrity URL=http://example.org/script.js
  desc 'Generate SRI integrity hash for a URL (argument: URL=...)'
  task :integrity do
    sha384 = `curl -L -s #{ENV.fetch('URL', nil)} | openssl dgst -sha384 -binary | openssl enc -base64 -A`
    puts "sha384-#{sha384}"
  end
end
