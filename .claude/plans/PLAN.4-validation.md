# 4-validation — Form objects, resource parser models, and Leaflet/OSM map widget

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`4-validation` (off `main`)

## Goal

Three coupled deliveries shipped as **two payload commits**:

1. **Form objects via `dry-validation`** — every user-input form (login, registration, password, new course, new event, new location, enrollment-by-email) routes through a Dry-Validation contract before reaching a service. Per-field errors render back into the same form (no redirect). `StringSecurity.entropy` powers password complexity.
2. **Resource parser models** — `Course`, `Event`, `Location`, `Enrollment`, `Attendance` wrap the API's JSON envelope and expose attributes / relationships / policies (consuming the policy summaries the API ships this week) as object methods. Replaces raw `course['attributes']['name']` reads in templates and controllers. The `Account` model's `admin?` / `course_creator?` predicates swap their rule logic from string-array-intersect to reading the API's `capabilities` envelope key. All parser models hydrate themselves via a `Model.from_api(envelope)` factory; `Model.new` becomes private.
3. **Map widget via Leaflet + OpenStreetMap** — `Location` envelope carries coordinates; the location-new form gets a Leaflet map widget for click-to-place markers; the attendance check-in flow renders a map with event location + an HTML5 geolocation prompt. **No API key required** (no Google, no provisioning). OSM tile-usage policy is satisfied by Leaflet's default attribution control.

Adapted from the reference branch.

## Strategy: Vertical Slice (Payload 1 — Forms + Parser Models + Helper Migration)

1. Add `dry-validation` gem; `app/forms/` directory; `require_app.rb` autoload.
2. `StringSecurity` lib — Shannon entropy calculator.
3. `Form` base + helpers — `USERNAME_REGEX`, `EMAIL_REGEX`, `Form.validation_errors(validation)`.
4. Form contracts: `LoginCredentials`, `Registration`, `Passwords`, `NewCourse`, `NewEvent`, `NewLocation`, `EnrollmentByEmail`.
5. Resource parser models: `Course`, `Event`, `Location`, `Enrollment`, `Attendance`. Each wraps the API envelope and exposes `attributes`, `relationships`, `policies` as object methods. Each owns its hydration via a `self.from_api(envelope_hash)` factory; `new` is `private_class_method`. App-side models carry no business logic — parsing is their purpose.
6. `Account` predicate rule-swap: `admin?` reads `@account_info.dig('capabilities', 'is_admin')`; `course_creator?` reads `@account_info.dig('capabilities', 'can_create_course')`. `role_for_course` / `student_in?` stay on `enrollments` reads (per-course, not actor-capabilities). Public method names stay the same; only rule implementations change. Add `Account.from_api` factory alongside existing `initialize`; mark `new` private; update existing callers.
7. Services that return resources call `Model.from_api(response.body)` and return the model instance. Services stay as pure orchestration (HTTP call → factory → return).
8. Controllers: every form-receiving route validates `routing.params` via the form contract first. On validation failure, set `flash[:error] = Form.validation_errors(...)` and **render the form view in place** (no `routing.redirect`). The view renders against `routing.params` so user-typed values stay populated.
9. Templates: switch from raw-hash reads (`course['attributes']['name']`) to parser-model getters (`course.name`) and policy-summary reads (`course.policies.can_edit`).
10. Tests: per-form unit specs (HAPPY + per-field SAD); parser-model unit specs covering `from_api` (HAPPY/SAD/EDGE) + getter / policy passthrough; integration spec updates asserting in-place render (HTTP 200 + same template + error in body), not redirect.

## Strategy: Vertical Slice (Payload 2 — Leaflet + OpenStreetMap map widget)

> No third-party provisioning. Leaflet via CDN with SRI hash; OSM tiles free under the tile-usage policy (modest volume + attribution rendered — both satisfied by default).

1. `_maps_loader.slim` — load Leaflet CSS + JS from CDN with SRI hashes (pin a specific Leaflet version); hard-code the OSM tile URL `https://tile.openstreetmap.org/{z}/{x}/{y}.png`. Lazy-loaded via `:maps` content block in `layout.slim` (only pages that need a map opt-in).
2. Location-picker widget (`_location_picker.slim`): `<div id="location-map">` + inline JS that initializes Leaflet, attaches a click handler that drops/moves a marker, writes the marker's `latlng` to hidden `latitude` / `longitude` form fields. `Form::NewLocation` validates the range.
3. Attendance check-in widget (`_attendance_map.slim`): event location marker + "Use my current location" button using `navigator.geolocation.getCurrentPosition` (browser-native consent prompt). On consent, drops a second marker for the student's position. Form submits both coordinate pairs (the student's coords are sent in anticipation of geofence eligibility, which lands in a later branch).
4. Failure handling:
   - **Leaflet fails to load** (CDN unreachable): detect via `<script onerror>` on the Leaflet `<script>` tag and/or `typeof L !== 'undefined'` check after a timeout. On detection, hide the map div and reveal numeric `latitude` / `longitude` inputs as a fallback.
   - **Tiles fail to load** (Leaflet loaded but OSM unreachable): listen for Leaflet's `tileerror` event on the map instance; same fallback.
   - **Geolocation denied** (student declines the browser consent prompt): show an inline error in the map area ("Location access required to check in."); disable the form submit button until coordinates are present; **render an explicit "Retry" button** that re-invokes `navigator.geolocation.getCurrentPosition` (per D3). If retry returns `PERMISSION_DENIED` (denied permanently), append the hint "Check-in requires location permission — adjust in browser site settings." Do not offer a "type your coordinates" manual fallback for check-in (would defeat the security check).
5. OSM attribution rendered automatically via Leaflet's `attributionControl` (verify enabled, not styled-out).
6. Tests: no live tile fetches in tests. Form-level coordinate-range validation already covered. Manual smoke test against live OSM tiles. Manual offline-dev smoke test (network offline → fallback to numeric inputs).

## Current State

- [ ] Plan created
- [ ] Branch `4-validation` created off `main`
- [ ] **Payload 1 — Forms + Parser Models + Helper Migration**
  - [ ] `dry-validation` gem; `app/forms/` directory + autoload
  - [ ] `StringSecurity.entropy` lib
  - [ ] `Form` base + i18n error YAML files
  - [ ] `LoginCredentials`, `Registration`, `Passwords` form contracts
  - [ ] `NewCourse`, `NewEvent`, `NewLocation`, `EnrollmentByEmail` form contracts
  - [ ] `Course`, `Event`, `Location`, `Enrollment`, `Attendance` parser models with `Model.from_api` factory + `private_class_method :new`
  - [ ] `Account` predicate rule-swap to `capabilities`-key reads; `Account.from_api` factory added; existing `Account.new` callers updated
  - [ ] Services updated to return parser models via `Model.from_api(...)`
  - [ ] Controllers: form contracts at every form-receiving route; in-place render on failure
  - [ ] Templates: raw-hash → parser-model getters; policy-summary reads; per-field error annotations
  - [ ] Form unit specs (`spec/forms/*_spec.rb`)
  - [ ] Parser-model unit specs (`spec/models/*_spec.rb`) — covers `from_api` HAPPY/SAD/EDGE
  - [ ] Integration specs updated for in-place render on validation failure
- [ ] **Payload 2 — Leaflet + OpenStreetMap map widget** (no provisioning required)
  - [ ] Leaflet CSS + JS via CDN with SRI hashes in `_maps_loader.slim`
  - [ ] `:maps` content block wiring in `layout.slim`
  - [ ] Location-picker widget (click-to-place marker → hidden lat/long)
  - [ ] Attendance check-in widget (event marker + HTML5 "Use my current location")
  - [ ] OSM attribution rendering verified
  - [ ] Failure-handling: Leaflet/tile load detection + geolocation-denied UX
  - [ ] Manual smoke test against live OSM tiles
- [ ] `rake spec` green
- [ ] `bundle exec rubocop .` green
- [ ] `bundle exec bundle-audit check --update` green
- [ ] Code review
- [ ] Diff review against the reference branch
- [ ] Commits shaped (2 payloads)
- [ ] Merge PR to `main` — deferred to user

## Key Findings

### Starting point (post `3-auth-token`)

- **Identity parser models exist** — `Account` and `CurrentSession` already shipped. Templates already call `@current_account.username` / `.admin?` / `.course_creator?` / `.student_in?(course_id)`. This week the *rule implementations* of `admin?` / `course_creator?` swap from `system_roles` string-array-intersect to `capabilities`-key reads. Public method names stay the same.
- **Resource hashes are raw everywhere else** — templates iterate `course['attributes']['name']`-style hashes. This branch introduces parser models so templates can write `course.name` / `course.policies.can_edit`.
- **`SecureMessage` + `RegistrationToken` libs exist** — tangential to validation; not touched this week.
- **No `dry-validation` gem yet** — added this branch.
- **All services accept `current_account` (the model)** — service signatures stay stable; form changes happen at the controller layer before reaching services.
- **`ApiClient` forwards Bearer auth_token** — no change this week.
- **`Account.new(...)` is called from multiple places** — at minimum `app/services/authenticate_account.rb` (from `3-auth-token`); may also appear in `app/controllers/auth.rb`, `app/controllers/account.rb`, and `spec/`. Grep is required before marking `new` private to avoid runtime `NoMethodError`s.

### Threat model delta vs `3-auth-token`

| Risk | Addressed here | Deferred |
| --- | --- | --- |
| App accepts unvalidated user input; API catches some but App gives no UX hint | Dry-Validation contracts at every form boundary; per-field error messages render in-place | Server-side validation is the API's concern |
| Password complexity enforced only by length / character regex | Shannon entropy floor of 3.0 — resists weak-but-long passwords like `aaaaaaaa` | Password breach lookup (deferred) |
| Username unicode confusables | `USERNAME_REGEX = /^[a-zA-Z0-9]+([._]?[a-zA-Z0-9]+)*$/` rejects entire non-ASCII surface | Full Unicode NFC normalization (deferred) |
| Authorization rules duplicated between API and App templates | Templates branch on `@course.policies.can_X` — single source of truth on the API. `Account` actor predicates read the API's `capabilities` envelope key. | — |
| Student location coordinate could be spoofed by typing | Check-in flow does not offer a "type your coordinates" fallback when geolocation is denied — only HTML5 geolocation populates the check-in coordinates | Server-side Haversine eligibility (deferred — App sends the coords this branch, API verifies next branch) |

## Questions

> Q1, Q2, … crossed off with decisions.

- [x] **Q1 (`Account` predicate rule-swap target).** API ships an actor-scoped `capabilities` key on the self-Account envelope, separate from the entity-scoped `policies` key on resource envelopes. App's `Account#admin?` reads `@account_info.dig('capabilities', 'is_admin') || false`; `course_creator?` reads `@account_info.dig('capabilities', 'can_create_course') || false`. Dig-with-fallback covers the edge case of an other-Account envelope mistakenly passed as `current_account`. `role_for_course` / `student_in?` stay on `enrollments` reads — per-course questions, not actor-capabilities.
- [x] **Q2 (resource parser models — where does hydration live?).** **Models own their own hydration** via `self.from_api(envelope_hash)` factory; `new` is `private_class_method`. Services stay as pure orchestration: `Course.from_api(ApiClient.get(...).body)` — one-line wrap, no parsing logic in services. App-side models carry no business logic — parsing is exactly what they should be doing.
- [x] **Q3 (validation error UX).** **Uniform render-in-place** across all forms. On failure, controller sets `flash[:error] = Form.validation_errors(...)` and renders the form view directly (no redirect). Roda's `flash` plugin makes `flash[:error] = ...` readable from the same request (verify the exact API in the plugin version we run; if it requires `flash.now[:error]`, swap accordingly — pattern stays the same). User-typed values preserved via `routing.params` on the re-rendered view.
- [x] **Q4 (map provider).** Leaflet + OpenStreetMap. No API key, no annual provisioning. Leaflet via CDN with SRI hashes; OSM tile URL hard-coded; attribution rendered automatically via Leaflet's `attributionControl`.
- [x] **Q5 (failure handling for the map widget).** Three distinct failure modes, three handlers (Strategy §Payload 2 §4): Leaflet load failure → fallback to numeric lat/long inputs; tile load failure → same; geolocation denied → inline error + disable submit (no manual-input bypass for check-in coordinates).

## Decisions (D1–D6)

Resolved 2026-05-21 — the items surfaced after closing Q1–Q5 (formerly tracked in the planning repo's `PENDING.decisions.md`, now deleted). D1, D4, D5, D6 are API-side (see `tyto2026-api/.claude/plans/PLAN.7-policies.md`). D2 and D3 are App-side, recorded below.

### D2 — `Model.from_api` SAD-path behavior (confirmed default)

Split treatment for malformed envelopes:

- **Required keys** (`type`, `attributes`, `id` within attributes): **raise** an explicit error (`KeyError` or a custom `Tyto::InvalidEnvelope`). The API is a trusted source; a missing `attributes` block means the API/App contract is broken — silent defaulting hides bugs.
- **Optional keys** (`policies`, `capabilities`, `include`/`relationships`): **default to empty `OpenStruct` / empty hash**. These are legitimately absent on responses from older API branches (pre-`7-policies`) and on other-Account envelopes (which lack `capabilities`). Defaulting lets templates that call `course.policies.can_edit` return `nil`/falsy without crashing.

**Test coverage** (already called out in Tasks → Tests below): per-model `from_api` spec covers HAPPY, SAD-required-missing (raises), SAD-optional-missing (hollow defaults).

### D3 — Geolocation-denied UX (overridden to explicit retry button)

**Overridden** from the original default (inline error + disabled submit, implicit "click the location button again" retry). Same security posture, clearer UI affordance.

**Resolution**: when the browser-native geolocation prompt is denied:

1. Inline error in the map area: "Location access required to check in."
2. Submit button stays disabled until coordinates are present.
3. **Explicit "Retry" button** alongside the error — re-invokes `navigator.geolocation.getCurrentPosition`. On `PERMISSION_DENIED` from the retry (denied permanently), append the follow-up hint *"Check-in requires location permission — adjust in browser site settings."*
4. **No manual-coordinate bypass** — typing the venue's coordinates would defeat the geofence security beat.

**Security model preserved**: the student's coordinate must come from the browser-supplied geolocation API; no spoofing vector via manual entry.

**Cascading edits applied** in Strategy §Payload 2 §4 and Tasks → Payload 2 → `_attendance_map.slim`.

### D1 (cross-reference) — `#index_summary` predicate set per policy

API-side resolution lives in `tyto2026-api/.claude/plans/PLAN.7-policies.md`. App-side impact: parser models pass `policies` through as `OpenStruct` regardless of whether the envelope carries the slim or full shape. Templates branch on whichever predicates they need — index templates read what `#index_summary` ships; detail templates read the full `#summary`. No App-side code change beyond what existing parser-model tasks already cover.

### D4 (cross-reference) — Actor-scoped predicates on `AccountPolicy`

API-side resolution lives in `tyto2026-api/.claude/plans/PLAN.7-policies.md`. App-side impact: the JSON envelope shape for `capabilities` is unchanged (`{ is_admin, can_create_course, can_manage_system_roles }`). The `Account#admin?` and `Account#course_creator?` predicates on the App-side parser model still read `@account_info.dig('capabilities', 'is_admin')` and `'can_create_course'`. The only difference is *where the rule lives on the API* — App contract surface is identical, so no App-side code change beyond existing tasks.

### D5 + D6 (cross-reference) — Capabilities-formalization + scope/policy-consistency slides land in week 13

Deck content lives in `13 - Policies and Validation.pptx`. Both confirmed for this semester. App-side slides (24–26) covered in the planning-repo plan's Deck update notes section.

## Scope

**In scope (Payload 1 — Forms + Parser Models + Helper Migration)**:

- Gemfile: add `gem 'dry-validation'`
- `app/forms/` + `require_app.rb` autoload
- `app/forms/form_base.rb`: `Tyto::Form` module with regex constants + helpers
- `app/forms/auth.rb`: `LoginCredentials`, `Registration`, `Passwords`
- `app/forms/new_course.rb`, `new_event.rb`, `new_location.rb`, `enrollment_by_email.rb`
- `app/forms/errors/`: per-form i18n YAML files
- `app/lib/string_security.rb`: `StringSecurity.entropy`
- `app/models/course.rb`, `event.rb`, `location.rb`, `enrollment.rb`, `attendance.rb` — parser models with `self.from_api` factory + `private_class_method :new`
- `app/models/account.rb` — rule-swap on `admin?` / `course_creator?` predicates to `capabilities`-key reads; add `self.from_api` factory; mark `new` private; update existing callers (grep `Account.new` across `app/` and `spec/`)
- Services updated to return parser models via `Model.from_api(...)`
- Controllers: form contracts at every form-receiving route; in-place render on failure
- Templates: parser-model getters + policy-summary reads + per-field error annotations + value preservation via `routing.params`
- Per-form, per-model, integration spec updates

**In scope (Payload 2 — Leaflet + OSM map widget; no provisioning)**:

- `app/presentation/views/_maps_loader.slim`: Leaflet CSS + JS via CDN with SRI hashes; hard-coded OSM tile URL; lazy via `:maps` content block
- `app/presentation/views/layout.slim`: `:maps` content block
- `app/presentation/views/_location_picker.slim`: click-to-place marker, writes to hidden form fields
- `app/presentation/views/_attendance_map.slim`: event location + HTML5 geolocation prompt
- `app/presentation/views/courses/locations/new.slim`: integrates picker
- `app/presentation/views/courses/show.slim` (or `_event_row.slim` student branch): integrates check-in map
- OSM attribution verified (required by tile-usage policy)
- Failure handling: Leaflet/tile detection + geolocation-denied UX
- Manual smoke test against live OSM tiles

**Out of scope** (deferred to later branches):

- Geofence eligibility check (Haversine distance)
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
7. **Parser models for entities** — wrap raw API hashes; expose `attributes` / `relationships` / `policies` as object methods; carry no business logic (parsing only).
8. **Actor capabilities surface** — `Account#admin?` / `course_creator?` read the API's `capabilities` envelope key. The App never re-implements the rule — it reads the API's decision.
9. **HTML5 geolocation consent** — `navigator.geolocation.getCurrentPosition` requires user consent via the browser-native prompt. The App cannot read coordinates silently. Check-in coordinates only come from geolocation (no manual-input bypass) so a denial halts the check-in flow rather than enabling spoofing.

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

- [ ] `app/models/course.rb`: `Course` with `self.from_api(course_info)` factory calling `process_attributes` / `process_relationships` / `process_policies`. Attributes: `id`, `name`, `description`. Relationships: `events` (array of `Event.from_api(...)`), `locations` (array of `Location.from_api(...)`), `enrollments` (array of `Enrollment.from_api(...)`). Policies via `OpenStruct.new(policies_hash || {})`. `private_class_method :new`.
- [ ] `app/models/event.rb`: `Event` — `from_api` parses `id`, `name`, `start_at`, `end_at`, `my_attendance_id`, nested `location` via `Location.from_api(...)`, `policies`. Add `live_now?` predicate (stateless utility against `Time.now`). `private_class_method :new`.
- [ ] `app/models/location.rb`: `Location` — `from_api` parses `id`, `name`, `latitude`, `longitude`, `policies`. `private_class_method :new`.
- [ ] `app/models/enrollment.rb`: `Enrollment` — `from_api` parses `id`, `account_id`, `course_id`, `role` (string name), nested `account` via `Account.from_api(...)`, `policies`. `private_class_method :new`.
- [ ] `app/models/attendance.rb`: `Attendance` — `from_api` parses `id`, `event_id`, `account_id`, `course_id`, `checked_in_at`, `policies`. `private_class_method :new`.

### Payload 1 — `Account` model updates

- [ ] **Grep for `Account.new` callers first**: `grep -rn 'Account\.new' app/ spec/` — note every caller so they can be updated alongside the `private_class_method :new` change.
- [ ] `app/models/account.rb`: add `self.from_api(account_info, auth_token=nil)` factory; add `process_capabilities(capabilities_hash)` that exposes `@capabilities` as an `OpenStruct` (mirrors `process_policies` on resource models; on other-Account envelopes the `capabilities` key is absent — `OpenStruct.new({})` so reads return `nil`/falsy without crashing).
- [ ] Swap `admin?` implementation from `@account_info.dig('include','system_roles').include?('admin')` to `@account_info.dig('capabilities','is_admin') || false`.
- [ ] Swap `course_creator?` to `@account_info.dig('capabilities','can_create_course') || false`.
- [ ] `role_for_course(course_id)` and `student_in?(course_id)` continue reading `enrollments`. Add a one-line class-level comment noting the three-way split: capabilities-backed actor predicates / enrollments-backed per-course predicates / `policies`-backed entity predicates (the last of which live on resource models, not `Account`).
- [ ] Mark `Account.new` private; update every caller surfaced by the grep (at minimum `AuthenticateAccount` service) to use `Account.from_api(...)`.

### Payload 1 — Services + Controllers

- [ ] `app/services/get_course.rb`: return `Course.from_api(ApiClient.get(...).body)`.
- [ ] `app/services/list_courses.rb`: return `response.body['data'].map { |c| Course.from_api(c) }`.
- [ ] `app/services/get_account.rb`: return `Account.from_api(ApiClient.get(...).body, nil)` (no token — viewing another account).
- [ ] `app/services/authenticate_account.rb`: swap `Account.new(...)` → `Account.from_api(...)` for entry-point uniformity.
- [ ] `app/controllers/auth.rb`: POST `/auth/login` validates via `LoginCredentials`; POST `/auth/register` via `Registration`.
- [ ] `app/controllers/account.rb`: POST `/account/:token` validates via `Passwords`.
- [ ] `app/controllers/courses.rb`: POST `/courses` via `NewCourse`; POST events / locations / enrollments via their contracts.
- [ ] Failed-validation paths: set `flash[:error] = Form.validation_errors(...)` and render the form view in place (no `routing.redirect`). Uniform across all forms.

### Payload 1 — Templates

- [ ] `register.slim`: per-field error annotation; values preserved via `routing.params`.
- [ ] `register_confirm.slim`, `login.slim`: same in-place render pattern.
- [ ] `courses/new.slim`, `courses/events/new.slim`, `courses/locations/new.slim`, `courses/enrollments/new.slim`: form contracts + error display + in-place render.
- [ ] `courses/index.slim`, `courses/show.slim`, `_event_row.slim`, `_location_row.slim`, `_enrollment_row.slim`, `_course_card.slim`, `account.slim`, `home.slim`: switch from raw-hash reads to parser-model getters and policy-summary reads.
- [ ] `_validation_errors.slim` (new partial): renders error list from `flash[:error]` for inline display at the top of each form template.

### Payload 1 — Tests

- [ ] `spec/forms/auth_spec.rb`: HAPPY + SAD per contract. Include entropy examples (`adf` ≈ 1.58 fails; `@3Fs^1HfaF$2` ≈ 3.41 passes) for the password rule.
- [ ] `spec/forms/new_course_spec.rb`, `new_event_spec.rb`, `new_location_spec.rb`, `enrollment_by_email_spec.rb`: HAPPY + SAD.
- [ ] `spec/lib/string_security_spec.rb`: entropy values.
- [ ] `spec/models/course_spec.rb`, `event_spec.rb`, `location_spec.rb`, `enrollment_spec.rb`, `attendance_spec.rb`: getter + policy passthrough. **`from_api` factory coverage**: HAPPY (well-formed envelope → fully populated model with nested associations parsed); SAD (missing `attributes` block → explicit raise); EDGE (missing `policies` key → policies-OpenStruct is empty; `course.policies.can_edit` returns nil/falsy without crashing). Also assert `Model.new` is private (`expect { Course.new(...) }.to raise_error(NoMethodError)`).
- [ ] `spec/models/account_spec.rb`: rule-swap coverage. HAPPY: `admin?` true when self-envelope has `capabilities.is_admin: true`; `course_creator?` true when `capabilities.can_create_course: true`. SAD: returns false when flag is false. EDGE: returns false (not nil) when `capabilities` key absent entirely.
- [ ] Integration specs: assert in-place render on validation failure (HTTP 200 + same form template + error in body), not redirect. Assert user-typed values appear in form fields on re-rendered page.

### Payload 2 — Leaflet + OSM widgets

- [ ] `app/presentation/views/_maps_loader.slim`: Leaflet CSS + JS via CDN with SRI hashes (pin specific Leaflet version, e.g. 1.9.x). Hard-code OSM tile URL `https://tile.openstreetmap.org/{z}/{x}/{y}.png`. Include `<script onerror>` handler on Leaflet's `<script>` tag plus `typeof L` post-load timeout check for failure detection. Lazy via `:maps` content block.
- [ ] `app/presentation/views/layout.slim`: `:maps` content block in `<head>`.
- [ ] `app/presentation/views/_location_picker.slim`: `<div id="location-map">` + inline JS — initialize Leaflet on the div, attach `click` handler that drops/moves a marker, write the marker's `latlng` to hidden `latitude` / `longitude` form fields. Verify `attributionControl` enabled.
- [ ] `app/presentation/views/courses/locations/new.slim`: includes `_location_picker.slim`; fallback to numeric lat/long inputs revealed by failure-detection JS (Leaflet load failure or tile load failure via `tileerror`).
- [ ] `app/presentation/views/_attendance_map.slim`: event location marker + "Use my current location" button. Button calls `navigator.geolocation.getCurrentPosition` with browser-native consent prompt. On success: drops student-position marker, enables form submit. **On denial (per D3)**: shows inline error ("Location access required to check in."), keeps submit disabled, renders an explicit **"Retry" button** that re-invokes `getCurrentPosition`. If the retry returns `PERMISSION_DENIED` (denied permanently), append the hint "Check-in requires location permission — adjust in browser site settings." **No manual-input bypass** for check-in coordinates — geolocation is the only path.
- [ ] `app/presentation/views/courses/show.slim` (or `_event_row.slim` student branch): "Check in" button reveals `_attendance_map.slim`; submission includes both coordinate pairs.

### Payload 2 — Tests + smoke test

- [ ] No live tile fetches in tests. Form-level coordinate-range validation already covered.
- [ ] **Manual smoke test**: location-new flow places a marker via click on the live Leaflet map; coordinates flow into the API; new location renders correctly. Check-in flow shows event location + student position (after granting browser geolocation consent).
- [ ] **Manual offline-dev smoke test**: DevTools → Network → "Offline" + reload; verify map div hides, numeric lat/long inputs appear; form still submits.
- [ ] **Manual geolocation-denial smoke test**: in DevTools or browser settings, deny location access; click "Use my current location"; verify inline error renders, submit stays disabled.
- [ ] **Manual attribution check**: confirm "© OpenStreetMap contributors" renders in the map's bottom-right corner.

### Verify

- [ ] `bundle exec rake spec` green
- [ ] `bundle exec rubocop .` green
- [ ] `bundle exec bundle-audit check --update` green
- [ ] Code review
- [ ] Diff review against the reference branch (`git show --name-status` + full-tree + shared-file content diff)
- [ ] Squash / split into 2 payload commits
- [ ] Merge PR to `main` — deferred to user

## Commit strategy

- **Required commit count**: **2 payloads** — Payload 1 (Credence-parity forms + parser models + helper migration) + Payload 2 (Leaflet/OSM map widget).
- **Final branch shape**:
  ```
  docs: plan 4-validation
  Uses form objects for validation of resource inputs                       ← Payload 1
  Adds Leaflet/OSM map widget for location selection and check-in           ← Payload 2
  ```
- **Payload 1 subject**: `Uses form objects for validation of resource inputs`. Body notes: 5 resource parser models with `Model.from_api` factory pattern; `Account` predicate rule-swap to `capabilities`-key reads; uniform in-place render on validation failure (no redirect); entropy + `USERNAME_REGEX` security framing.
- **Payload 2 subject**: `Adds Leaflet/OSM map widget for location selection and check-in`. Body notes: no API key (Leaflet via CDN + OSM tiles); attribution rendered via Leaflet's default control; failure handling for Leaflet/tile load + geolocation denial; check-in coords come from HTML5 geolocation only (no manual-input bypass); coordinate pairs sent to the API in anticipation of geofence eligibility (Haversine, deferred).

## Infrastructure setup

No infrastructure provisioning required this branch. Leaflet ships via CDN (free, no signup); OpenStreetMap tile use is governed by OSM's tile-usage policy (free for modest volume + attribution rendered — both satisfied by Leaflet's default `attributionControl`).

The only manual verification step is post-deploy:

1. **Verify production**: after deploying the App's `4-validation` branch to Heroku, visit the new-location page and confirm the map renders + OSM attribution is visible in the bottom-right corner. Visit a course detail page with a live event as a student and verify the check-in map shows the event marker + the browser-native geolocation consent prompt fires on "Use my current location."

## Open agenda items

None. All Q1–Q5 and D1–D6 items are resolved (see Questions and Decisions sections above). The planning-repo plan at `baby_tyto/.claude/plans/PLAN.app.4-validation.md` carries the deck update notes and any future cross-repo coordination.

## Completed

(to be filled in during implementation)

## Post-Implementation Notes (for reviewer)

(to be filled in before handing off for review)

---

Last updated: 2026-05-21 (Q1–Q5 + D1–D6 resolved — `from_api` split raise/default; explicit "Retry" button on geolocation denial with no manual-coord bypass; cross-references to API-side D1/D4/D5/D6. Planning-repo plan at `baby_tyto/.claude/plans/PLAN.app.4-validation.md` is the canonical source for Q/D resolutions and deck update notes.)
