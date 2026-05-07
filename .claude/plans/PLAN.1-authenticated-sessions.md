# 1-authenticated-sessions — Web App: login, sessions, full course/event/location/enrollment UI

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update before and after task and subtask implementations.

## Branch

`1-authenticated-sessions` — the **first** branch in this repo. `main` is currently empty (no commits).

## Goal

Bootstrap the Tyto web application from scratch and ship the first piece of user-facing functionality: a login form that posts credentials to the API's `POST /api/v1/auth/authenticate` route, stores the authenticated account in a Rack session cookie, and exercises the full API surface — index/detail/create flows for courses, events, locations, and enrollments.

The app has **no database of its own** — it's a thin presentation layer that talks to `tyto2026-api` via the `http` gem.

Adapted from the reference web App branch, with a deliberate scope expansion: the reference shipped only home + login + account profile. Tyto ships those plus full CRUD-create flows (no edit/delete except enrollment removal) so the API surface introduced in this week's API branch is fully exercised end-to-end.

## Strategy: Vertical Slice

1. **Bootstrap the repo** — empty project + `.gitignore` on `main` (a single commit on `main`).
2. **Branch `1-authenticated-sessions`** off the new `main`.
3. **Plan-first commit** on the branch.
4. **Payload commit** that ships:
   - Roda app skeleton, sessions, layout, login/logout flow, account profile.
   - A reusable `ApiClient` + service objects for every authenticated API call.
   - Index + detail + create flows for courses, events, locations, enrollments.
   - Geolocation-only (browser API, no map widget) location creation, with hard failure on permission denial.

## Current State

- [x] Plan created
- [x] Starter commit on `main` (`Empty project with gitignore`)
- [x] Branch `1-authenticated-sessions` created off `main`
- [x] Plan committed as `docs: plan 1-authenticated-sessions`
- [x] `CLAUDE.local.md` created and points at this plan
- [x] All payload tasks below
- [x] Manual flow verified end-to-end against the API
- [x] Code review
- [x] Retrospective migration audit
- [x] Squash to 1 payload commit on the branch
- [ ] Merge PR to `main` — deferred to user, done manually later in the week after class

## Key Findings

### Starting point

This repo is an empty git repo on `main`, no commits, no files. Everything is greenfield. The matching API branch `4-authenticate` provides the auth endpoint and the (also-ungated) resource endpoints this app calls.

### Threat model delta vs no-app-yet

| Risk | Addressed here | Deferred (per project rules) |
| --- | --- | --- |
| Credentials in URL or query string | Login form `POST`s to `/auth/login`; service object `POST`s to API with JSON body | — |
| Session data sent in clear cookies | `Rack::Session::Cookie` with secret-based HMAC integrity (Rack default) | Cookie encryption with RbNaCl SecretBox |
| Session secret in source | `SESSION_SECRET` lives in Figaro-managed `config/secrets.yml` (gitignored); `secrets.example.yml` ships with a placeholder | — |
| Auth state replay | Session cookie has 30-day expiry (`ONE_MONTH`) | Server-side session pool / Redis |
| **CSRF** | **Intentionally NOT addressed** — flagged as known weakness | Deferred to a later branch covering security headers & request signing |
| **API trust model** | App login gate is presentation-layer only; API trusts client-supplied `current_account_id` | Encrypted token + scope-aware policies in later branches |
| Geolocation permission denied | Hard fail with flash error — no manual fallback | Manual lat/lon entry + form-level validation in a later branch |

### Domain scope

No models in the app. All persistence is via the API. The session stores the authenticated account as the `attributes` hash from the auth response (which includes `id` and embedded `enrollments`). UI gating uses `current_account['include']['enrollments']` to decide which create-* buttons to show on the course detail page (defense in depth — the API is the actual enforcer).

## Decisions

- **D1** — Login required for everything except `/`, `/auth/login`. Even resource indexes (`GET /courses`) require login on the app side.
- **D2** — CSRF protection deferred. Flagged in handoff doc.
- **D3** — Geolocation: browser's `navigator.geolocation.getCurrentPosition` only. No map widget. No manual fallback this week — if permission denied or coordinates unavailable, show flash error and the user cannot create a location.
- **D4** — Service objects own ad-hoc validation (matches `AuthenticateAccount`). Controllers stay thin.
- **D5** — `_method=DELETE` form button via Roda `:all_verbs` plugin for remove-enrollment.
- **D6** — Session strategy: `Rack::Session::Cookie` (not Pool/Redis).
- **D7** — UI gates the create-* buttons by reading `current_account['include']['enrollments']` for the course; the API is the actual enforcer.
- **D8** — Bootstrap **5.3.3** via jsDelivr CDN; theme: Cerulean via Bootswatch.
- **D9** — No Font Awesome / Bootstrap-Social CDN this week (re-add when SSO arrives).
- **D10** — `.ruby-version` = `4.0.2` (matches API).
- **D11** — `TargetRubyVersion: 4.0` in `.rubocop.yml`.
- **D12** — Secrets filename: `config/secrets.example.yml` (dot-style).

## Questions

- [x] **Q1 — Logo asset**: resolved. Use the live tyto.tw owl logo. Source file at `/Users/soumyaray/Sync/Dropbox/ossdev/projects/tyto-dev/tyto/frontend_app/static/favicon.png` (200×200, stylized barn-owl face on cream/tan circle, amber palette). Implementation phase: `cp` it to `app/presentation/public/logo.png`; style in `nav.slim` at ~35px tall.

## Scope

**In scope:**

Repo bootstrap:
- `.gitignore` on `main`.

Roda + Figaro + sessions:
- `config.ru`, `config/environments.rb`, `config/secrets.example.yml`, `require_app.rb`, `Rakefile`, `Gemfile`, `LICENSE`, `README.md`, `.ruby-version`, `.rubocop.yml`, `spec/test_load_all.rb`.

Controllers:
- `app/controllers/app.rb` — App class with `:render`/`:assets`/`:public`/`:multi_route`/`:flash`/`:all_verbs` plugins; before-route `@current_account = session[:current_account]` and login-gate redirect for protected paths; root → home view.
- `app/controllers/auth.rb` — login GET/POST, logout GET.
- `app/controllers/account.rb` — profile + my-courses (reads `current_account['include']['enrollments']`).
- `app/controllers/courses.rb` — index, new, show (with nested events/locations/enrollments sections), create. Nested resources live inside this file under `routing.on String do |course_id|`, mirroring the API's organization.

Service objects (in `app/services/`):
- `api_client.rb` — base helper with `get(path)`, `post(path, body)`, `delete(path)` and `authenticated_post(path, body, current_account_id:)` / `authenticated_delete(path, current_account_id:)`.
- `authenticate_account.rb` — `POST /auth/authenticate`; returns the `attributes` hash on 200.
- `list_courses.rb`, `get_course.rb`, `get_account.rb` — read services.
- `create_course.rb`, `create_event_for_course.rb`, `create_location_for_course.rb`, `enroll_account_in_course.rb`, `remove_enrollment.rb` — write services with ad-hoc validation.

Slim views (under `app/presentation/views/`):
- Top-level: `layout.slim`, `nav.slim`, `flash_bar.slim`, `home.slim`, `login.slim`, `account.slim`.
- `courses/`: `index.slim`, `new.slim`, `show.slim`, `events/new.slim`, `locations/new.slim`, `enrollments/new.slim`.
- Partials: `_course_card.slim`, `_event_row.slim`, `_location_row.slim`, `_enrollment_row.slim`, `_role_badge.slim`.

Static assets:
- `app/presentation/assets/css/style.css` — `.force-wrap` + role-badge color classes if Bootstrap defaults aren't sufficient.
- `app/presentation/public/logo.png` — copy of the live tyto.tw owl logo (per Q1).

Tooling:
- `Rakefile` with `style`, `console`, `generate:session_secret`, `run:dev` (port 9292).

**Out of scope** (deferred per project rules):

- Encrypted sessions / Redis / `SecureSession`
- Email verification + auth-token flow
- Form objects / dry-validation
- Google Maps embedding
- Google OAuth
- Security headers / CSP / signed requests / **CSRF protection**
- Course / event / location editing or deletion (only enrollment removal is in scope this week)
- Attendance check-in
- Geolocation permission-denied fallback (manual entry)

## Intentional Weaknesses

These exist on purpose so each week's lecture has a clear "before/after" arc:

1. **API trust model**: API trusts client-supplied `current_account_id` in POST/DELETE bodies. A malicious client can impersonate anyone. Will be addressed by encrypted tokens + policies in later branches.
2. **No CSRF protection**: app forms are CSRF targets. Will be addressed when CSP / signed requests land.
3. **Cookie session is signed but not encrypted**: `current_account['email']` and `current_account['include']['enrollments']` are visible in the cookie. Encryption arrives next branch.
4. **No rate limiting on login**: brute-force the login form is unmitigated.

## Tasks

> Check tasks off as soon as each one is finished — do not batch.

### Phase A — repo bootstrap on `main`

- [x] 1. Create `.gitignore` with: `_*`, `config/secrets.yml`, `*.log`, `.DS_Store`, `tmp/`, `.bundle/`, `vendor/bundle`, `CLAUDE.local.md`, `.claude/*`, `!.claude/CLAUDE.md`, `!.claude/settings.json`, `!.claude/skills/`, `!.claude/plans/`. Keep `Gemfile.lock` tracked.
- [x] 2. Commit on `main` as `Empty project with gitignore`.

### Phase B — branch + plan commit

- [x] 3. Create branch `1-authenticated-sessions` off the new `main`.
- [x] 4. Commit `.claude/plans/PLAN.1-authenticated-sessions.md` as `docs: plan 1-authenticated-sessions`.
- [x] 5. Create `CLAUDE.local.md` pointing at `@.claude/plans/PLAN.1-authenticated-sessions.md`.

### Phase C — config + tooling

- [x] 6. Add `.ruby-version` = `4.0.2`.
- [x] 7. Add `.rubocop.yml` with `TargetRubyVersion: 4.0`, `NewCops: enable`, `rubocop-performance` plugin, `Metrics/BlockLength` excluded for `spec/**/*`, `Rakefile`, `app/controllers/*.rb`.
- [x] 8. Add `Gemfile`:
  - Web: `puma`, `roda`, `slim`, `rack-session`
  - Configuration: `figaro`
  - Encoding: `base64`
  - Communication: `http`
  - Security: `rbnacl`
  - Debugging: `pry`
  - `:development`: `rake`, `rubocop`, `rubocop-performance`, `bundler-audit`
  - `:development, :test`: `rack-test`, `rerun`
- [x] 9. `bundle install` → `Gemfile.lock`.
- [x] 10. Add `LICENSE` (GPLv3, matching API repo).
- [x] 11. Add `README.md` — Tyto-specific copy: web app for Tyto course-attendance system; references the API repo; install/test/execute instructions; `rake run:dev` on port 9292.
- [x] 12. Add `Rakefile` with: `print_env`, `console` → `pry -r ./spec/test_load_all`, `style` → `rubocop .`, `generate:session_secret` (RbNaCl 64-byte random, base64), `run:dev` → `puma -p 9292`.
- [x] 13. Add `config.ru` → `Tyto::App.freeze.app`.
- [x] 14. Add `require_app.rb` (globs `app/services` and `app/controllers` plus `config`).
- [x] 15. Add `config/environments.rb`:
  - `Tyto::App < Roda` with `:environments` plugin
  - Figaro setup (`config/secrets.yml` path)
  - `def self.config = Figaro.env`
  - `ONE_MONTH = 30 * 24 * 60 * 60`
  - `use Rack::Session::Cookie, expire_after: ONE_MONTH, secret: config.SESSION_SECRET`
  - `:common_logger` for dev/prod
  - `Logger.new($stderr)` and `def self.logger`
  - dev/test logger level → `Logger::ERROR`
  - dev/test pry hookup
- [x] 16. Add `config/secrets.example.yml` with dev/test envs containing `API_URL: http://localhost:3000/api/v1`, `APP_URL: http://localhost:9292`, `SESSION_SECRET: some_secret`.
- [x] 17. Generate a real session secret (`rake generate:session_secret`), copy into `config/secrets.yml` (gitignored).
- [x] 18. Add `spec/test_load_all.rb` for pry session bootstrapping + `Rack::Test::Methods` mixin in non-prod.

### Phase D — controllers

- [x] 19. Add `app/controllers/app.rb`:
  - `class App < Roda` with plugins: `:render` (slim, views `app/presentation/views`), `:assets` (css `style.css`, path `app/presentation/assets`), `:public` (root `app/presentation/public`), `:multi_route`, `:flash`, `:all_verbs`
  - Top-level `route do |routing|`: set `Content-Type: text/html; charset=utf-8`, set `@current_account = session[:current_account]`, dispatch `routing.public`/`routing.assets`/`routing.multi_route`, root → `view 'home', locals: { current_account: @current_account }`
  - **Login gate**: a private `require_login!(routing)` helper that halts with redirect to `/auth/login` if `@current_account` is nil. Each protected controller calls it at the top of its route block.
- [x] 20. Add `app/controllers/auth.rb`:
  - `route('auth')` block
  - `routing.is 'login'`:
    - `routing.get` → `view :login`
    - `routing.post` → call `AuthenticateAccount.new(App.config).call(username:, password:)`, store in `session[:current_account]`, set `flash[:notice] = "Welcome back #{account['username']}!"`, redirect `/`
    - On `StandardError`: `flash.now[:error] = '...'`, `response.status = 400`, render `view :login`
  - `routing.on 'logout'`:
    - `routing.get` → clear `session[:current_account]`, redirect `'/auth/login'`
- [x] 21. Add `app/controllers/account.rb`:
  - `route('account')`; calls `require_login!(routing)`
  - `routing.get String do |username|`: if `@current_account['username'] == username`, render `view :account, locals: { current_account: @current_account }`; else redirect to the user's own account page.
- [x] 22. Add `app/controllers/courses.rb`:
  - `route('courses')`; calls `require_login!(routing)` at the top
  - `routing.is 'new'` → GET renders `courses/new.slim`
  - `routing.on String do |course_id|`:
    - `routing.on 'events' do`: `routing.is 'new'` → GET renders form; `routing.post` → `CreateEventForCourse...call(...)` with `current_account_id`
    - `routing.on 'locations' do`: `routing.is 'new'` → GET; `routing.post` → `CreateLocationForCourse...`
    - `routing.on 'enrollments' do`:
      - `routing.is 'new'` → GET; `routing.post` → `EnrollAccountInCourse...`
      - `routing.on String do |enrollment_id|; routing.delete do` → `RemoveEnrollment.new(App.config).call(...)` with `current_account_id`
    - `routing.get` (no remainder) → `view 'courses/show', locals: { course: GetCourse.call(course_id) }`
  - `routing.get` (root) → `view 'courses/index', locals: { courses: ListCourses.call }`
  - `routing.post` (root) → `CreateCourse.new(App.config).call(...)` with `current_account_id`

### Phase E — services

- [x] 23. Add `app/services/api_client.rb`:
  - `class ApiClient` with `initialize(config)` storing `@config`
  - `get(path)`, `post(path, body)`, `delete(path)` — wrap `HTTP.get/post/delete` against `"#{@config.API_URL}#{path}"`
  - Raise `ApiClient::ApiError < StandardError` on non-2xx; include status + parsed body
  - `authenticated_post(path, body, current_account_id:)` — merges `current_account_id` into body
  - `authenticated_delete(path, current_account_id:)` — sends `current_account_id` as JSON body on DELETE
- [x] 24. Add `app/services/authenticate_account.rb`:
  - `UnauthorizedError < StandardError`
  - `call(username:, password:)` → `HTTP.post("#{config.API_URL}/auth/authenticate", json: {username:, password:})`; on non-200 raise; on 200 return `response.parse['attributes']` merged with the response's `include` hash so the session stores enrollments alongside account fields
- [x] 25. Add `app/services/list_courses.rb` — `GET /courses`; returns parsed array.
- [x] 26. Add `app/services/get_course.rb` — chains `GET /courses/:id`, `GET /courses/:id/events`, `GET /courses/:id/locations`, `GET /courses/:id/enrollments`; returns a single hash with all four. Cleaner than 4 separate calls in the controller.
- [x] 27. Add `app/services/get_account.rb` — `GET /accounts/:username`; returns full account hash including `include.enrollments`.
- [x] 28. Add `app/services/create_course.rb`:
  - Ad-hoc validation: `name` non-empty + length 1..200; `description` optional, length 0..2000
  - `call(current_account_id:, name:, description:)` → `authenticated_post('/courses', {name:, description:}, current_account_id:)`
- [x] 29. Add `app/services/create_event_for_course.rb`:
  - Ad-hoc validation: `name` non-empty + length; `start_at` / `end_at` parseable with `Time.iso8601` (after converting `datetime-local`'s `YYYY-MM-DDTHH:MM` → ISO 8601 by appending `:00`); `start_at < end_at`; `location_id` integer-coerceable
  - `call(current_account_id:, course_id:, name:, start_at:, end_at:, location_id:)`
- [x] 30. Add `app/services/create_location_for_course.rb`:
  - Ad-hoc validation: `name` non-empty + length; `latitude` numeric in `-90.0..90.0`; `longitude` numeric in `-180.0..180.0`
  - `call(current_account_id:, course_id:, name:, latitude:, longitude:)`
- [x] 31. Add `app/services/enroll_account_in_course.rb`:
  - Ad-hoc validation: `username` regex `/\A\w{4,}\z/`; `role_name` ∈ `%w[owner instructor staff student]`
  - `call(current_account_id:, course_id:, username:, role_name:)` → `authenticated_post("/courses/#{course_id}/enrollments/#{username}", {role_name:}, current_account_id:)`
- [x] 32. Add `app/services/remove_enrollment.rb`:
  - `call(current_account_id:, course_id:, enrollment_id:)` → `authenticated_delete("/courses/#{course_id}/enrollments/#{enrollment_id}", current_account_id:)`

### Phase F — views + assets

- [x] 33. Add `app/presentation/views/layout.slim`:
  - `doctype html`, `<html><head>` with `title Tyto`
  - Bootstrap 5.3.3 themed CSS via Bootswatch (`https://bootswatch.com/5/cerulean/bootstrap.min.css`) + custom `assets(:css)`
  - Body: Popper + Bootstrap 5.3.3 JS via jsDelivr CDN with current SRI hashes
  - `render :nav`, container with `render :flash_bar` and `yield`
- [x] 34. Add `app/presentation/views/home.slim`:
  - `h1 Welcome to Tyto`
  - Tyto-purpose paragraph (geo-attendance for courses)
  - Reminder: teaching demo, not for live grading
  - If `current_account` is nil → link to `/auth/login`; else link to `/courses`
- [x] 35. Add `app/presentation/views/login.slim`:
  - **No** Font Awesome / Bootstrap-Social CDN links
  - 3-column responsive form: username + password inputs, primary submit button, `method='post' action='/auth/login'`
- [x] 36. Add `app/presentation/views/nav.slim`:
  - Bootstrap 5 navbar, dark primary background; brand → logo + text linking `/`
  - Logged-in: `Courses` nav link active; account dropdown with `account` and `logout`
  - Logged-out: link to `/auth/login` (active); placeholder `register` link disabled
- [x] 37. Add `app/presentation/views/flash_bar.slim`:
  - Bootstrap 5 `alert alert-danger` for `flash[:error]`, `alert alert-success` for `flash[:notice]`, with id attributes for testability
- [x] 38. Add `app/presentation/views/account.slim`:
  - Bootstrap row/col grid showing `current_account['username']`, `current_account['email']`, `current_account['id']`
  - `h2 My Courses` followed by a list of `current_account['include']['enrollments']`; each row shows course name + role badge
- [x] 39. Add `app/presentation/views/courses/index.slim`:
  - `h1 Courses` + `Create Course` link button (`/courses/new`)
  - For each course: `_course_card.slim` partial
  - Empty-state message if no courses
- [x] 40. Add `app/presentation/views/courses/new.slim`:
  - Form: `name` text input (required, maxlength 200), `description` textarea (maxlength 2000), submit button
  - `method='post' action='/courses'`
- [x] 41. Add `app/presentation/views/courses/show.slim`:
  - Course header (name, description)
  - Three sections: Events, Locations, Enrollments — each a list of partials
  - Conditional create-* buttons gated by a `role_for_course(course_id, current_account)` view helper that reads `current_account['include']['enrollments']`
- [x] 42. Add `app/presentation/views/courses/events/new.slim`:
  - Form: `name`, `<input type="datetime-local" name="start_at">`, `<input type="datetime-local" name="end_at">`, `<select name="location_id">` populated with the course's locations, submit
- [x] 43. Add `app/presentation/views/courses/locations/new.slim`:
  - Form: `name`, hidden `latitude` + `longitude` inputs, "Get my current location" button (type='button'), submit button (disabled until lat/lon are filled)
  - Inline `<script>`: on button click, `navigator.geolocation.getCurrentPosition(success, error)`. Success → fill hidden inputs + enable submit. Error → alert + form rejects submit (D3 — hard fail)
- [x] 44. Add `app/presentation/views/courses/enrollments/new.slim`:
  - Form: `username` text input, `role_name` `<select>` with options `owner` / `instructor` / `staff` / `student`, submit
- [x] 45. Add partials:
  - `_course_card.slim` — name, description preview, link to `/courses/[id]`
  - `_event_row.slim` — name, start_at (formatted), end_at (formatted), location name
  - `_location_row.slim` — name, lat (4 decimals), lon (4 decimals)
  - `_enrollment_row.slim` — username, role badge, "Remove" form button (DELETE) visible only if `current_account` is owner/instructor/staff for the course
  - `_role_badge.slim` — Bootstrap badge with color per role (`bg-warning` owner, `bg-primary` instructor, `bg-info` staff, `bg-secondary` student)
- [x] 46. Add `app/presentation/assets/css/style.css` — `.force-wrap` rule + minor role-badge tuning if Bootstrap defaults aren't sufficient.
- [x] 47. Add `app/presentation/public/logo.png` — `cp /Users/soumyaray/Sync/Dropbox/ossdev/projects/tyto-dev/tyto/frontend_app/static/favicon.png app/presentation/public/logo.png` (live tyto.tw owl logo, per Q1).

### Verify

- [x] 48. `bundle exec rake style` — clean.
- [x] 49. `bundle exec rake console` — pry boots without error.
- [x] 50. Boot `tyto2026-api` on port 3000 (`rake run:dev`).
- [x] 51. Boot `tyto2026-app` on port 9292 (`rake run:dev`).
- [x] 52. Manual flow — login: visit `/`, click `login`, submit a seeded account → expect redirect to `/` with welcome flash.
- [x] 53. Manual flow — login (BAD): submit wrong password → expect 400, login page with red flash.
- [x] 54. Manual flow — courses index: click `Courses` → expect list of seeded courses.
- [x] 55. Manual flow — create course: `Create Course` → fill form → expect new course visible in index.
- [x] 56. Manual flow — course detail: click a course → expect three sections (events, locations, enrollments).
- [x] 57. Manual flow — create location: `Add Location` → `Get my current location` → grant permission → submit → expect new row.
- [x] 58. Manual flow — create location (BAD): deny permission → expect alert + form rejects submit.
- [x] 59. Manual flow — create event: `Add Event` → fill form (using location dropdown) → submit → expect new row.
- [x] 60. Manual flow — enroll: `Enroll Member` → username + role → submit → expect new enrollment row.
- [x] 61. Manual flow — remove enrollment: `Remove` button → expect enrollment removed.
- [x] 62. Manual flow — account profile: visit `/account/[username]` → expect username, email, and `My Courses` listing.
- [x] 63. Manual flow — logout: click `logout` → expect redirect to `/auth/login`, session cleared.
- [x] 64. Verify session cookie in DevTools — confirm signed but not encrypted (visible base64 payload).
- [x] 65. Code review.
- [x] 66. Retrospective migration audit:
  - `git -C <ref-app> show --name-status <ref-starter-sha>` → matches main commit
  - `git -C <ref-app> show --name-status <ref-payload-sha>` → reconcile every entry against payload commit. Tyto adds many files the reference didn't (services for full CRUD, views for index/new/show flows, partials) — these are intentional scope expansion (documented in this plan's Goal). Files the reference shipped that Tyto matches 1:1 (modulo domain swap): `Gemfile`, `.rubocop.yml`, `.ruby-version`, `LICENSE`, `README.md`, `Rakefile`, `config.ru`, `config/environments.rb`, `config/secrets.example.yml`, `require_app.rb`, `spec/test_load_all.rb`, `app/controllers/app.rb`, `app/controllers/auth.rb`, `app/controllers/account.rb`, `app/services/authenticate_account.rb`, all 6 base view files, `style.css`, `logo.png`.
  - Full-tree diff — note version-pin differences (Bootstrap 5.0 → 5.3, Ruby 3.3 → 4.0) and dropped CDNs (Font Awesome / Bootstrap-Social) as intentional adaptations.
  - Content diff on shared filenames — every difference must be a domain swap, version pin, or noted preference.
- [x] 67. **Author handoff doc** for `/ppt-update`: write `baby_tyto/design-notes/auth-trust-model-week-10.md` covering the intentional weaknesses (D2 + D3 + API trust model) plus the Account `id` deviation. Shared task with the API branch.
- [x] 68. Squash to 1 payload commit on the branch.
- [ ] 69. Merge PR to `main` — deferred to user, done manually later in the week after class.
- [x] 70. **Skill self-reflection**: re-read `/week-plan` SKILL.md and propose refinements if this week surfaced any gaps.

## Commit strategy

- **`main`**: 1 commit, subject `Empty project with gitignore`. Adds `.gitignore` only.
- **Branch `1-authenticated-sessions`**: 2 commits:
  1. `docs: plan 1-authenticated-sessions` — plan file only (scaffolding, not a payload commit per project rules).
  2. **Payload commit, subject `Homepage and login page`**. Body covers:
     - Roda app scaffold + sessions
     - Login flow + `AuthenticateAccount` service
     - Slim views with Bootstrap 5.3 (theme: Cerulean)
     - Full course/event/location/enrollment index + create flows (scope expansion vs reference — documented)
     - Geolocation-only location creation (no map this week)
     - Version bumps: Bootstrap 5.0 → 5.3, Ruby 3.3 → 4.0
     - Deferred: CSRF, Font Awesome / Bootstrap-Social (per project rules)
- **Required count from reference**: 1 payload commit on the branch — matched.

## Completed

Shipped as a single payload commit `Homepage and login page` on `1-authenticated-sessions`, sitting on top of the `Empty project with gitignore` starter commit on `main`. All in-scope items landed: Roda + Figaro + Rack::Session::Cookie skeleton, Slim + Bootstrap 5.3.3 Cerulean views, login/logout/account flow, full course/event/location/enrollment index + create flows (scope expansion vs reference), geolocation-only location creation (hard-fail on permission denied), `ApiClient` + per-call services threading `current_account_id` through to the API. Logo copied from full-Tyto (Q1 resolution). Manual flow walked end-to-end against `tyto2026-api` on port 3000. Handoff doc for `/ppt-update` lives at `baby_tyto/design-notes/auth-trust-model-week-10.md` (shared with the API branch).

## Post-Implementation Notes (for reviewer)

- Q1 (logo): used the live tyto.tw owl from `frontend_app/static/favicon.png`.
- Scope expansion vs reference: reference app shipped only home + login + account profile; Tyto adds full course/event/location/enrollment index + create flows so the API surface introduced in `4-authenticate` is fully exercised. Documented in this plan's Goal.
- Intentional weaknesses for `/ppt-update`: client-supplied `current_account_id` (API trust gap), no CSRF, signed-but-not-encrypted cookie, no rate limiting, geolocation hard-fail with no manual fallback. All covered in `baby_tyto/design-notes/auth-trust-model-week-10.md`.
- Geolocation TODO recorded: D3 — deferred manual lat/lon entry to `4-validation`.
- Account `id` deviation: matches the API's D3 — App stores `current_account['id']` in the session so it can include it in authenticated POST/DELETE bodies. Deliberate scaffolding for the trust-gap demo; closed by encrypted tokens in `3-auth-token`.

## Carryover for future branches

- **Account first/last names**: this week's `_enrollment_row.slim` displays `account.username` (added to the API's Enrollment envelope as a follow-up to `4-authenticate`) as a pragmatic stand-in for a full name. When registration ships (App branch `3-auth-token`, paired with API `6-auth-token`), the form should collect `first_name` / `last_name`; update the Slim partials (`_enrollment_row.slim`, `account.slim`, `nav.slim`) to render the proper name once the API surfaces it.

---

Last updated: 2026-04-28
