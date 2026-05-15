# frozen_string_literal: true

require 'http'
require 'json'
require 'uri'

module Tyto
  # Shared helper for HTTP calls to the Tyto API.
  # Authenticated calls pass `auth_token:` as a kwarg; it is forwarded
  # as an `Authorization: Bearer <token>` header (never in the body).
  class ApiClient
    # Wraps a non-2xx API response with parsed body for the caller to inspect.
    class ApiError < StandardError
      attr_reader :status, :body

      def initialize(status, body)
        @status = status
        @body = body
        super(body.is_a?(Hash) ? body['message'].to_s : body.to_s)
      end
    end

    def initialize(config)
      @config = config
    end

    def get(path, params: {}, auth_token: nil)
      full_path = params.empty? ? path : "#{path}?#{URI.encode_www_form(params)}"
      parse(http(auth_token).get(url(full_path)))
    end

    def post(path, body, auth_token: nil)
      parse(http(auth_token).post(url(path), json: body))
    end

    def put(path, body = {}, auth_token: nil)
      parse(http(auth_token).put(url(path), json: body))
    end

    def delete(path, body = nil, auth_token: nil)
      request = http(auth_token).headers('Content-Type' => 'application/json')
      response = body ? request.delete(url(path), body: body.to_json) : request.delete(url(path))
      parse(response)
    end

    private

    def http(auth_token)
      auth_token ? HTTP.auth("Bearer #{auth_token}") : HTTP
    end

    def url(path)
      "#{@config.API_URL}#{path}"
    end

    def parse(response)
      raw = response.body.to_s
      parsed = raw.empty? ? {} : JSON.parse(raw)
      raise ApiError.new(response.code, parsed) unless (200..299).cover?(response.code)

      parsed
    end
  end
end
