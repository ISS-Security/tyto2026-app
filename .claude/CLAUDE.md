# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project context

`tyto2026-app` is the **server-rendered web frontend** (Roda + Slim) for the Tyto course-attendance system. It is a thin presentation layer over the Tyto API (`tyto2026-api`); the API owns the database and enforces all authorization. This app is responsible only for sessions, login flow, form validation, and rendering.

This is a **teaching project**. The branch sequence (`1-authenticated-sessions`, `2-...`, etc.) introduces one security concept at a time. Each branch has a plan at `.claude/plans/PLAN.<branch>.md`; once finalized those plans are static historical records — do not `@`-import them. Active working notes live in `CLAUDE.local.md` (gitignored).

## Common commands

```shell
bundle install
cp config/secrets.example.yml config/secrets.yml
bundle exec rake generate:session_secret   # paste output into secrets.yml under development:
bundle exec rake run:dev                   # puma on :9292 (API must be on :3000 first)
bundle exec rake style                     # rubocop
bundle exec rake console                   # pry with app loaded via spec/test_load_all.rb
bundle exec rake url:integrity URL=...     # SRI sha384 hash for a CDN asset
```

There are no automated tests. Verification is manual against a running API — see the branch plan's manual flow checklist.

## Architecture

### Roda routing tree

`Tyto::App` is a single Roda class reopened across `app/controllers/`:

- `config/environments.rb` — declares `Tyto::App < Roda`, wires Figaro (`App.config`), the `LOGGER`, and `Rack::Session::Cookie` (1-month expiry, `SESSION_SECRET`).
- `app/controllers/app.rb` — base routing block. Sets `@current_account = session[:current_account]`, mounts `routing.public` / `routing.assets` / `routing.multi_route`, and serves `GET /`. Defines two private helpers used by the other controllers: `require_login!(routing)` and `roles_for_course(course_id, current_account)`.
- `app/controllers/auth.rb`, `account.rb`, `courses.rb` — each `require_relative 'app'` and call `route('auth')` / `route('account')` / `route('courses')` to register a sub-tree under `multi_route`.

`config.ru` runs `Tyto::App.freeze.app`. `require_app.rb` recursively `require`s every `.rb` under `config/`, `app/lib/`, `app/services/`, `app/controllers/`, so adding a new file in those directories is enough — no manual wiring.

### Service objects

Every controller action that talks to the API delegates to a class in `app/services/` (e.g. `AuthenticateAccount`, `CreateCourse`, `GetCourse`, `EnrollAccountInCourse`). Conventions:

- Constructor takes the Figaro config: `Service.new(App.config)`.
- Public entry point is `#call(...)` with keyword args.
- Input validation raises a service-local error class (e.g. `InvalidInput`, `UnauthorizedError`).
- All HTTP goes through `Tyto::ApiClient` (`app/services/api_client.rb`), which wraps non-2xx responses in `ApiClient::ApiError` (carrying `status` and parsed `body`).

`ApiClient#authenticated_post` / `#authenticated_delete` inject `current_account_id` into the body; for GETs the controller/service passes it explicitly via `params:`. The API uses that field to enforce authorization — never call the API without it for protected routes.

### Session shape

After login, `session[:current_account]` holds the API's account `attributes` hash merged with `'include' => { 'enrollments' => [...] }`. Anything reading enrollments (e.g. `roles_for_course`) walks `current_account['include']['enrollments']`. Keep this shape stable when changing the auth flow.

### Views

Slim templates under `app/presentation/views/`. Partials are `_name.slim` and rendered via `render :name`. The layout pulls Bootstrap 5.3 (Cerulean) from a CDN with **SRI integrity hashes** — when bumping a CDN URL, regenerate the hash with `rake url:integrity URL=...`.

### Gitignore quirk

The top-level `.gitignore` excludes everything matching `_*`, then re-includes `app/presentation/views/_*.slim` and a few `.claude/` paths. This is why partials use the `_` prefix and why `_snippets/` (teaching scratch like `demo-cookie-decode.rb`) stays out of git. RuboCop also excludes `_snippets/**/*`.

## Conventions

- All app code lives under `module Tyto`.
- Every Ruby file starts with `# frozen_string_literal: true`.
- Controllers reopen `class App < Roda` (do not subclass); Rubocop's `Metrics/ClassLength` and `Metrics/BlockLength` are already relaxed for `app/controllers/*.rb`.
- Errors from services bubble up to the controller, which catches `StandardError` (or `ApiClient::ApiError`), sets a `flash[:error]`, and redirects to a sensible form/index page. Match this pattern in new actions rather than rendering inline error pages.
