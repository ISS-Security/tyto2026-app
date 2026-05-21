# 4-validation — Form objects, resource parser models, and Google Maps integration

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`4-validation` (off `main`)

## Goal

Three coupled deliveries shipped as **two payload commits**:

1. **Form objects via `dry-validation`** — every user-input form (login, registration, password, new course, new event, new location, enrollment-by-email) routes through a Dry-Validation contract before reaching a service. Per-field errors render back into the form. `StringSecurity.entropy` powers password complexity.
2. **Resource parser models** — `Course`, `Event`, `Location`, `Enrollment`, `Attendance` wrap the API's JSON envelope and expose attributes / relationships / policies (consuming the policy summaries the API ships this week) as object methods. Replaces raw `course['attributes']['name']` reads in templates and controllers. The `Account` model's `admin?` / `course_creator?` predicates swap their **rule logic** from string-array-intersect to policy-summary reads.
3. **Google Maps integration** — `Location` envelope carries coordinates; the location-new form gets a map widget for click-to-place markers; the attendance check-in flow renders a map with event location + a geolocation prompt. Depends on a user-provisioned Google Maps JS API key (see Infrastructure setup) and requires design discussion before implementation.

Adapted from the reference branch.

## Strategy: Vertical Slice (Payload 1 — Forms + Parser Models + Helper Migration)

1. Add `dry-validation` gem; `app/forms/` directory; `require_app.rb` autoload.
2. `StringSecurity` lib — Shannon entropy calculator.
3. `Form` base + helpers — `USERNAME_REGEX`, `EMAIL_REGEX`, `Form.validation_errors(validation)`.
4. Form contracts: `LoginCredentials`, `Registration`, `Passwords`, `NewCourse`, `NewEvent`, `NewLocation`, `EnrollmentByEmail`.
5. Resource parser models: `Course`, `Event`, `Location`, `Enrollment`, `Attendance`. Each wraps the API envelope and exposes `attributes`, `relationships`, `policies` as object methods.
6. `Account` predicate rule-swap: `admin?` / `course_creator?` shift from string-array-intersect on `system_roles` to reading the API's policy summary. Method names stay; rule implementations change.
7. Services that return resources now wrap them in parser models before returning.
8. Controllers: every form-receiving route validates `routing.params` via the form contract first; failure flashes `Form.validation_errors(...)` and either redirects or re-renders with stashed values (per Q3).
9. Templates: switch from raw-hash reads (`course['attributes']['name']`) to parser-model getters (`course.name`) and policy-summary reads (`course.policies.can_edit`).
10. Tests: per-form unit specs (HAPPY + per-field SAD); parser-model getter / policy passthrough specs; integration spec updates for the new validation-failure path.

## Strategy: Vertical Slice (Payload 2 — Google Maps integration; discuss before implementation)

> Depends on a user-provisioned Maps JS API key (Infrastructure setup §2). Implementation scope can be sketched this week; live render blocks on the key.

1. User provisions a new restricted Maps JS API key. Restrictions: HTTP referrer to dev + production hostname; API scope to Maps JavaScript API only.
2. Figaro: `GOOGLE_MAPS_API_KEY` in `config/secrets.yml`. Heroku `config:set` for production.
3. `_maps_loader.slim` — single inline `<script>` block loading Maps JS with key from server-side config. Lazy-loaded via `:maps` content block in `layout.slim` (only pages that need Maps opt-in).
4. Location-picker widget: `<div id="map">` + click-to-place marker JS; writes to hidden `latitude` / `longitude` fields. `Form::NewLocation` validates coordinate range.
5. Attendance check-in widget: event location marker + "Geolocate me" button using `navigator.geolocation`. Form submits both coordinate pairs.
6. Offline / no-key fallback (per Q5): silent fall-back to numeric inputs in dev; hard error in production.
7. Tests: form-level coordinate-range validation. No live Maps in tests. Manual smoke test blocks on the user-provisioned key.

## Current State

- [ ] Plan created
- [ ] Branch `4-validation` created off `main`
- [ ] **Payload 1 — Forms + Parser Models + Helper Migration**
  - [ ] `dry-validation` gem; `app/forms/` directory + autoload
  - [ ] `StringSecurity.entropy` lib
  - [ ] `Form` base + i18n error YAML files
  - [ ] `LoginCredentials`, `Registration`, `Passwords` form contracts
  - [ ] `NewCourse`, `NewEvent`, `NewLocation`, `EnrollmentByEmail` form contracts
  - [ ] `Course`, `Event`, `Location`, `Enrollment`, `Attendance` parser models
  - [ ] `Account` predicate rule-swap (admin?, course_creator?)
  - [ ] Services updated to return parser models
  - [ ] Controllers: form contracts at every form-receiving route
  - [ ] Templates: raw-hash → parser-model getters; policy-summary reads
  - [ ] Form unit specs (`spec/forms/*_spec.rb`)
  - [ ] Parser-model unit specs (`spec/models/*_spec.rb`)
  - [ ] Integration specs updated
- [ ] **Payload 2 — Google Maps integration** (discuss before implementing)
  - [ ] User provisions Maps API key (blocked on user)
  - [ ] Figaro / Heroku env vars
  - [ ] `_maps_loader.slim` + `:maps` content-block wiring
  - [ ] Location-picker widget
  - [ ] Attendance check-in widget
  - [ ] Offline fallback
  - [ ] Manual smoke test against live Maps
- [ ] `rake spec` green
- [ ] `bundle exec rubocop .` green
- [ ] `bundle exec bundle-audit check --update` green
- [ ] Code review
- [ ] Retrospective migration audit
- [ ] Commits shaped (2 payloads)
- [ ] Merge PR to `main` — deferred to user
- [ ] Skill self-reflection

## Key Findings

### Starting point (post `3-auth-token`)

- **Identity parser models exist** — `Account` and `CurrentSession` already shipped. Templates already call `@current_account.username` / `.admin?` / `.course_creator?` / `.student_in?(course_id)`. This week the *rule implementations* of `admin?` / `course_creator?` swap from string-array-intersect to policy-summary reads; the public method names stay.
- **Resource hashes are raw everywhere else** — templates iterate `course['attributes']['name']`-style hashes. This branch introduces parser models so templates can write `course.name` / `course.policies.can_edit`.
- **`SecureMessage` + `RegistrationToken` libs exist** — tangential to validation; not touched this week.
- **No `dry-validation` gem yet** — added this branch.
- **All services accept `current_account` (the model)** — service signatures stay stable; form changes happen at controller layer before reaching services.
- **`ApiClient` forwards Bearer auth_token** — no change this week.

### Threat model delta vs `3-auth-token`

| Risk | Addressed here | Deferred |
| --- | --- | --- |
| App accepts unvalidated user input; API catches some but App gives no UX hint | Dry-Validation contracts at every form boundary; per-field error messages | Server-side validation is the API's concern |
| Password complexity enforced only by length / character regex | Shannon entropy floor of 3.0 — resists weak-but-long passwords like `aaaaaaaa` | Password breach lookup deferred per project rules |
| Username unicode confusables | `USERNAME_REGEX = /^[a-zA-Z0-9]+([._]?[a-zA-Z0-9]+)*$/` rejects entire non-ASCII surface | Full Unicode NFC normalization deferred per project rules |
| Authorization rules duplicated between API and App templates | Templates branch on `@course.policies.can_X` — single source of truth on the API | Predicates on `Account` swap to policy-summary reads this week |
| Maps API key necessarily client-facing | HTTP-referrer restriction + scope restriction in Google Cloud console; lazy-load on pages that need Maps | Server-side proxy deferred (and Maps JS API requires browser load) |

## Questions

> Q1, Q2, … crossed off with decisions.

- [ ] **Q1 (`Account#admin?` / `course_creator?` rule swap depends on API shape)**: does the API ship a per-account policy summary (`{type: 'account', policies: {admin: true, course_creator: true}}`)?
  - If yes: `Account#admin?` reads `@account_info.dig('policies','admin')`. Clean rule swap.
  - If no (only per-resource summaries): `Account#admin?` stays on string-array-intersect over `system_roles`. Acceptable but less clean.
  - **Decision lands when the API plan's matching question resolves.** Discuss before this week's implementation.
- [ ] **Q2 (parser models — wrap in services or in controllers?)**: services parse JSON → return parser-model instances, or services return hashes and controllers wrap?
  - Recommended: **services wrap** — keeps controllers thin; services are already the HTTP-response boundary.
- [ ] **Q3 (validation error UX — flash+redirect or render-in-place?)**:
  1. Flash + redirect (simple; loses typed values; user re-types)
  2. Render-in-place (stash values + errors in session; pre-fill form)
  - Recommended: **(2) for data-rich forms** (registration, new course); **(1) for simple forms** (login). Lecture can teach the contrast.
- [ ] **Q4 (Maps key provisioning timing)**: provision before class (Payload 2 fully testable live during lecture) or after class (Payload 2 ships as code + stubs only this week)?
  - Open. Discuss week-of.
- [ ] **Q5 (Maps fallback when key absent)**: silent stub, visible dev warning, or hard production error?
  - Recommended: **silent in dev** (form remains testable), **hard error in production**. Lecture can demo the dev fallback explicitly.

## Scope

**In scope (Payload 1 — Forms + Parser Models + Helper Migration)**:

- Gemfile: add `gem 'dry-validation'`
- `app/forms/` + `require_app.rb` autoload
- `app/forms/form_base.rb`: `Tyto::Form` module with regex constants + helpers
- `app/forms/auth.rb`: `LoginCredentials`, `Registration`, `Passwords`
- `app/forms/new_course.rb`, `new_event.rb`, `new_location.rb`, `enrollment_by_email.rb`
- `app/forms/errors/`: per-form i18n YAML files
- `app/lib/string_security.rb`: `StringSecurity.entropy`
- `app/models/course.rb`, `event.rb`, `location.rb`, `enrollment.rb`, `attendance.rb` — parser models
- `app/models/account.rb` — rule-swap on `admin?` / `course_creator?` predicates (per Q1 resolution)
- Services updated to return parser models per Q2
- Controllers: form contracts at every form-receiving route
- Templates: parser-model getters + policy-summary reads
- Per-form, per-model, integration spec updates

**In scope (Payload 2 — Google Maps; discuss before implementing)**:

- `GOOGLE_MAPS_API_KEY` env var (Figaro + Heroku)
- `_maps_loader.slim` + layout content-block wiring
- `_location_picker.slim`: click-to-place marker, writes to hidden form fields
- `_attendance_map.slim`: event location + geolocate-me button
- `courses/locations/new.slim` integrates picker; falls back to numeric inputs per Q5
- `courses/show.slim` (or `_event_row.slim` student branch) integrates check-in map
- Offline fallback
- Manual smoke test against live key

**Out of scope** (deferred per project rules):

- Geolocation eligibility check (Haversine distance)
- SSO via Google OAuth
- Browser security headers (CSP, X-Frame-Options)
- Admin members listing page
- Per-event attendance roster UI for teaching staff
- Staff "toggle attendance" UI
- Full Unicode NFC normalization on username input

## Security Concerns Addressed This Week

1. **Validating user input** — defensive layer at every form boundary. Catches formatting mistakes, missing/unnecessary fields, malicious payloads.
2. **Username unicode confusables** — `USERNAME_REGEX` restricts to ASCII alphanumerics + dots; rejects entire non-ASCII attack surface.
3. **Password entropy** — Shannon entropy ≥ 3.0 via `StringSecurity.entropy`. Resists weak-but-long passwords.
4. **Form contracts via `dry-validation`** — declarative rules + per-form custom error messages via i18n YAML.
5. **Email validation futility** — `EMAIL_REGEX = /@/`. Email correctness verified via verification-link round-trip, not via regex.
6. **App-side policy summary consumption** — templates branch on `@course.policies.can_edit` instead of re-implementing the rule. Single source of truth lives on the API.
7. **Parser models for entities** — wrap raw API hashes; `OpenStruct` over `policies` block gives `.can_X` accessor.
8. **API key management as a class of secret** (Payload 2) — Maps JS key *must* be client-facing. Contrast with server-only secrets like `DB_KEY` / `MSG_KEY`. Mitigation is restriction by HTTP referrer + API scope in the Google Cloud console.

## Tasks

> Check tasks off as soon as each one is finished — do not batch.

### Setup

- [ ] Create branch `4-validation` off `main`
- [ ] Update `CLAUDE.local.md` to point at this plan
- [ ] Plan-first commit (`docs: plan 4-validation`)

### Payload 1 — Gemfile + scaffolding

- [ ] Gemfile: `gem 'dry-validation'`; `bundle install`
- [ ] `app/forms/` directory + `require_app.rb` includes `'forms'`
- [ ] `app/lib/string_security.rb`: `StringSecurity.entropy(string)`

### Payload 1 — Form base + i18n

- [ ] `app/forms/form_base.rb`: `Tyto::Form` module with `USERNAME_REGEX`, `EMAIL_REGEX`, `self.validation_errors`, `self.message_values`
- [ ] `app/forms/errors/account_details.yml`, `password.yml`, `new_course.yml`, `new_event.yml`, `new_location.yml`, `enrollment.yml`

### Payload 1 — Form contracts

- [ ] `app/forms/auth.rb`: `LoginCredentials`, `Registration`, `Passwords`
- [ ] `app/forms/new_course.rb`: `NewCourse` (name presence + length 1-200)
- [ ] `app/forms/new_event.rb`: `NewEvent` (name, start_at, end_at with start<end rule, location_id)
- [ ] `app/forms/new_location.rb`: `NewLocation` (name, latitude -90..90, longitude -180..180)
- [ ] `app/forms/enrollment_by_email.rb`: `EnrollmentByEmail` (email format, role_name in `%w[owner instructor staff student]`)

### Payload 1 — Parser models

- [ ] `app/models/course.rb`: `Course` with `process_attributes` / `process_relationships` / `process_policies`. Attributes: `id`, `name`, `description`. Relationships: `events` (array of `Event`), `locations` (array of `Location`), `enrollments` (array of `Enrollment`). Policies via `OpenStruct.new(policies_hash)`.
- [ ] `app/models/event.rb`: `Event` — `id`, `name`, `start_at`, `end_at`, `my_attendance_id`, nested `location` (parsed `Location`), `policies`. `live_now?` predicate.
- [ ] `app/models/location.rb`: `Location` — `id`, `name`, `latitude`, `longitude`, `policies`.
- [ ] `app/models/enrollment.rb`: `Enrollment` — `id`, `account_id`, `course_id`, `role` (string name), nested `account`, `policies`.
- [ ] `app/models/attendance.rb`: `Attendance` — `id`, `event_id`, `account_id`, `course_id`, `checked_in_at`, `policies`.

### Payload 1 — `Account` rule swap

- [ ] `app/models/account.rb`: swap `admin?` implementation per Q1.
- [ ] Swap `course_creator?` similarly.
- [ ] Document `role_for_course` / `student_in?` as still using `enrollments` (per-course; the per-account policy summary doesn't cover them naturally).

### Payload 1 — Services + Controllers

- [ ] `app/services/get_course.rb`: return `Course.new(api_response)` per Q2.
- [ ] `app/services/list_courses.rb`: return `[Course]` array.
- [ ] `app/services/get_account.rb`: return `Account.new(api_response, nil)`.
- [ ] `app/controllers/auth.rb`: POST `/auth/login` validates via `LoginCredentials`; POST `/auth/register` via `Registration`.
- [ ] `app/controllers/account.rb`: POST `/account/:token` validates via `Passwords`.
- [ ] `app/controllers/courses.rb`: POST `/courses` via `NewCourse`; POST events / locations / enrollments via their contracts.
- [ ] Failed-validation paths: flash + redirect (simple forms per Q3) or render-in-place (data-rich forms per Q3).

### Payload 1 — Templates

- [ ] `register.slim`: per-field error annotation; preserved values on failure (per Q3).
- [ ] `register_confirm.slim`, `login.slim`: per Q3.
- [ ] `courses/new.slim`, `courses/events/new.slim`, `courses/locations/new.slim`, `courses/enrollments/new.slim`: form contracts + error display.
- [ ] `courses/index.slim`, `courses/show.slim`, `_event_row.slim`, `_location_row.slim`, `_enrollment_row.slim`, `_course_card.slim`, `account.slim`, `home.slim`: switch from raw-hash reads to parser-model getters and policy-summary reads.
- [ ] `_validation_errors.slim` (new partial): renders error list for simple-flash forms.

### Payload 1 — Tests

- [ ] `spec/forms/auth_spec.rb`: HAPPY + SAD per contract. Include entropy examples for password rule.
- [ ] `spec/forms/new_course_spec.rb`, `new_event_spec.rb`, `new_location_spec.rb`, `enrollment_by_email_spec.rb`: HAPPY + SAD.
- [ ] `spec/lib/string_security_spec.rb`: entropy values.
- [ ] `spec/models/course_spec.rb`, `event_spec.rb`, `location_spec.rb`, `enrollment_spec.rb`, `attendance_spec.rb`: getter + policy passthrough.
- [ ] `spec/models/account_spec.rb`: rule-swap coverage.
- [ ] Integration specs: assert redirect-on-validation-failure for simple-flash forms.

### Payload 2 — Maps infrastructure (blocked on user)

- [ ] **User**: provision new restricted Google Maps JS API key. Restrictions: HTTP referrer to dev + production; API scope to Maps JavaScript API only.
- [ ] **User**: `GOOGLE_MAPS_API_KEY` in `config/secrets.yml` (dev/test) + `heroku config:set` (prod).
- [ ] `config/secrets.example.yml`: add `GOOGLE_MAPS_API_KEY: ''` placeholder.

### Payload 2 — Widgets

- [ ] `app/presentation/views/_maps_loader.slim`: inline `<script>` loads Maps JS API with key from server config; lazy via content block.
- [ ] `app/presentation/views/layout.slim`: `:maps` content block.
- [ ] `app/presentation/views/_location_picker.slim`: `<div id="location-map">` + click-to-place marker JS; writes hidden lat/long fields.
- [ ] `app/presentation/views/courses/locations/new.slim`: includes picker; falls back to numeric inputs per Q5.
- [ ] `app/presentation/views/_attendance_map.slim`: event location marker + geolocate-me button.
- [ ] `app/presentation/views/courses/show.slim` (or `_event_row.slim`): "Check in" reveals attendance map; submission includes coordinate pairs.

### Payload 2 — Tests + smoke test

- [ ] No live Maps in tests. Form-level coordinate-range validation already covered.
- [ ] **Manual smoke test (blocked on user-provisioned key)**: location-new flow places a marker via click; coordinates flow into API; new location renders correctly. Check-in flow shows event location + student position.
- [ ] **Manual offline smoke test** (key absent in dev): location-new falls back to numeric inputs; form still submits.

### Verify

- [ ] `bundle exec rake spec` green
- [ ] `bundle exec rubocop .` green
- [ ] `bundle exec bundle-audit check --update` green
- [ ] Code review
- [ ] Retrospective migration audit (`git show --name-status` + full-tree + shared-file content diff)
- [ ] Squash / split into 2 payload commits
- [ ] Merge PR to `main` — deferred to user, done manually after class
- [ ] Skill self-reflection

## Commit strategy

- **Required commit count**: **2 payloads** — adapted parity + Maps extension.
- **Final branch shape**:
  ```
  docs: plan 4-validation
  Uses form objects for validation of resource inputs                ← Payload 1
  Adds Google Maps for location selection and check-in               ← Payload 2
  ```
- **Payload 1 subject**: `Uses form objects for validation of resource inputs`. Body notes: 5 resource parser models, `Account` rule-swap per Q1, validation-UX choice per Q3, entropy + `USERNAME_REGEX` security framing.
- **Payload 2 subject**: `Adds Google Maps for location selection and check-in`. Body notes: Maps API key as a class-of-secret, offline fallback per Q5, Q4 provisioning timing, App sends coordinate pairs in anticipation of geofence eligibility (deferred per project rules).

## Infrastructure setup (user-operated)

These are reference instructions for the user, not tasks for the AI. The AI provides commands; the user runs them.

1. **Provision a Google Maps JS API key** (a new key, not reused from any other project):
   - Google Cloud console → APIs & Services → Credentials → Create credentials → API key
   - Restrictions:
     - Application: HTTP referrers → `http://localhost:9292/*` (dev) + production hostname
     - API: Maps JavaScript API only
   - Copy the key into a password manager (Google Cloud does not re-reveal API keys)
2. **Local secrets** (`config/secrets.yml`) for `development` and `test`:
   ```yaml
   GOOGLE_MAPS_API_KEY: <pasted key>
   ```
3. **Heroku production env-var**:
   ```bash
   heroku config:set -a tyto2026-app GOOGLE_MAPS_API_KEY=<paste>
   ```
4. **Verify production**: after deploy, visit the new-location page and confirm the map renders. If not, check Google Cloud console restrictions for referrer match.

## Open agenda items for this week's class discussion

1. **API per-account policy summary (yes/no)** — gates this branch's `Account#admin?` rule-swap.
2. **Validation UX (flash+redirect vs render-in-place)** — impacts every form template + controller failure branch.
3. **Maps key provisioning timing** — gates Payload 2 live testing.
4. **Maps lecture slot** — is there time in the week-13 deck for a Maps + class-of-secret slide? If not, defer the lecture beat; ship code anyway.

## Completed

(to be filled in during implementation)

## Post-Implementation Notes (for reviewer)

(to be filled in before handing off for review)

---

Last updated: 2026-05-21 (plan created)
