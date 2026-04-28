# frozen_string_literal: true

require 'http'
require 'json'
require 'uri'

module Tyto
  # Shared helper for HTTP calls to the Tyto API.
  class ApiClient
    # Wraps a non-2xx API response with parsed body for the caller to inspect.
    class ApiError < StandardError
      attr_reader :status, :body

      def initialize(status, body)
        @status = status
        @body = body
        super("API error #{status}: #{body['message']}")
      end
    end

    def initialize(config)
      @config = config
    end

    def get(path, params: {})
      full_path = params.empty? ? path : "#{path}?#{URI.encode_www_form(params)}"
      parse(HTTP.get(url(full_path)))
    end

    def post(path, body)
      parse(HTTP.post(url(path), json: body))
    end

    def delete(path, body = nil)
      request = HTTP.headers('Content-Type' => 'application/json')
      response = body ? request.delete(url(path), body: body.to_json) : request.delete(url(path))
      parse(response)
    end

    def authenticated_post(path, body, current_account_id:)
      post(path, body.merge(current_account_id: current_account_id))
    end

    def authenticated_delete(path, current_account_id:)
      delete(path, { current_account_id: current_account_id })
    end

    private

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
