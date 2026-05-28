# frozen_string_literal: true

require_relative 'spec_helper'

# Regression guards for bugs surfaced during the week-13 manual smoke
# test (2026-05-21). Where a full behavioral test would require Rack::Test
# + WebMock + encrypted-session scaffolding the App doesn't yet have,
# we check the lexical shape of the fix instead — brittle but high-signal
# against accidental re-introduction.

describe 'Regression: params helper is defined on Tyto::App' do
  # Without `params` exposed as an instance helper on Tyto::App, every
  # form template that reads `value=(params['key'] || '')` crashes with
  # NameError on render. Slim binds its eval scope to the App instance.
  it 'Tyto::App exposes a private params method' do
    _(Tyto::App.private_instance_methods).must_include :params
  end
end

describe 'Regression: account controller does not flatten API response' do
  # account.slim reads `account['attributes']['username']` (nested envelope).
  # An earlier admin-view-other branch flattened the response via
  # `response.fetch('attributes').merge('include' => response['include'])`
  # which broke the template with NoMethodError on nil.
  it 'admin-view path passes the full envelope (no .fetch.merge flatten)' do
    src = File.read(File.expand_path('../app/controllers/account.rb', __dir__))
    _(src).wont_match(/response\.fetch\(['"]attributes['"]\)\.merge/)
  end
end

describe 'Regression: account API key is shown only on the self-view' do
  # The READ_ONLY key is the *viewed* account's key. Showing it when an admin
  # views someone else would leak a usable key, so the controller passes
  # `api_key` only when is_self, and the view gates the block on it. The key
  # comes from `account.auth_token` (the fetched READ_ONLY token), never from
  # the cached session account, so the full session token can't leak.
  it 'controller passes the read-only key only on the self-view' do
    src = File.read(File.expand_path('../app/controllers/account.rb', __dir__))
    _(src).must_match(/api_key:\s*\(is_self \? account\.auth_token : nil\)/)
  end

  it 'account.slim gates the API Access block on is_self && api_key' do
    src = File.read(File.expand_path(
                      '../app/presentation/views/account.slim', __dir__
                    ))
    _(src).must_match(/if is_self && api_key/)
  end
end

describe 'Regression: _attendance_map.slim quotes UUID event id' do
  # event.id is a UUID (string with hyphens). Unquoted interpolation
  # produces `var eventId = 01899a10-485e-4929-...;` which JS parses
  # as a malformed scientific-notation literal ("missing exponent").
  it 'event id is interpolated as a quoted JS string literal' do
    src = File.read(File.expand_path(
                      '../app/presentation/views/_attendance_map.slim', __dir__
                    ))
    _(src).must_match(/var eventId = "/)
  end
end

describe 'Regression: flash_bar.slim skips Hash-shaped errors' do
  # Hash-shaped flash[:error] payloads belong to the in-form
  # _validation_errors.slim partial. flash_bar.slim renders only
  # string-shaped errors so the layout bar doesn't dump raw
  # `{username: "must be filled", ...}` text above the form.
  it 'flash_bar guards against Hash-shaped flash[:error]' do
    src = File.read(File.expand_path(
                      '../app/presentation/views/flash_bar.slim', __dir__
                    ))
    _(src).must_match(/is_a\?\(Hash\)/)
  end
end

describe 'Regression: Account#admin? + course_creator? read capabilities' do
  # Q1 rule-swap. Predicates must read the actor-scoped capabilities key,
  # not the entity-scoped system_roles array. Already covered by
  # spec/models/account_spec.rb with behavioral tests; this is a
  # belt-and-suspenders source check against accidental revert.
  let(:src) { File.read(File.expand_path('../app/models/account.rb', __dir__)) }

  it 'admin? reads capabilities[is_admin]' do
    _(src).must_match(/def admin\?\s*\n\s*capabilities\[['"]is_admin['"]\]/)
  end

  it 'course_creator? reads capabilities[can_create_course]' do
    _(src).must_match(/def course_creator\?\s*\n\s*capabilities\[['"]can_create_course['"]\]/)
  end
end
