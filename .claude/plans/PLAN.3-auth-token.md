# 3-auth-token — Email-verified registration and Bearer-token API calls

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`3-auth-token`

## Goal

Switch the App from one-step registration (`POST /auth/register` → account exists) to a **two-step email-verified flow** that pairs with the API's new `/auth/register` endpoint, and forward the new API-issued `auth_token` as `Authorization: Bearer <token>` on every subsequent API call. The App no longer sends `current_account_id` in any request body.

Three coupled pieces:

1. `VerifyRegistration` service (new): SimpleBox-encrypts `{email, username}` into a URL-safe registration token via the existing `SecureMessage` library, attaches a verification URL to the registration data, and POSTs to the API's `/auth/register`. The API sends the verification email; the App never sees the user's intended password until they click the link.
2. `GET /auth/register/:token` route + `register_confirm.slim` view: decrypts the registration token and shows the password-entry form. The form POSTs to `/account/:token`, which decrypts the token a second time and calls the existing `CreateAccount` service.
3. `auth_token` storage in the encrypted session + `ApiClient` Bearer forwarding on every authenticated call.

## Strategy: Vertical Slice

1. **Service layer** — `VerifyRegistration` (new), `AuthenticateAccount` updated to parse the new API envelope, `ApiClient` updated to forward an optional Bearer token kwarg.
2. **Session plumbing** — `SecureSession` stores `:auth_token` alongside `:current_account`. Logout deletes both.
3. **Controller flow** — `auth.rb`: `POST /auth/register` calls `VerifyRegistration` (not `CreateAccount`); `GET /auth/register/:token` decrypts the token and renders the password form. `account.rb`: `POST /account/:token` decrypts the token and calls `CreateAccount`.
4. **View layer** — `register.slim` simplified to email + username; `register_confirm.slim` new.
5. **Service refactor for Bearer** — every existing service that talks to the API drops `current_account_id` from its call signature and accepts / forwards `auth_token:` to `ApiClient`.
6. **Controllers consume the new shape** — `courses.rb` and `account.rb` read `auth_token` from session, pass it through to services.
7. **Tests** — Update `service_authenticate_spec.rb` for the new envelope. Add `service_verify_registration_spec.rb` (WebMock for API). Update `service_create_account_spec.rb` if its signature changes.

## Current State

- [ ] Plan created
- [ ] Branch `3-auth-token` created off `main`
- [ ] `VerifyRegistration` service added
- [ ] `AuthenticateAccount` parses new envelope (`{attributes: {account, auth_token}}`)
- [ ] `ApiClient` forwards Bearer auth_token
- [ ] `SecureSession` stores `:auth_token`
- [ ] `/auth/register` flow split into email-send + token-confirm
- [ ] `/account/<token>` POST creates account with password
- [ ] `register.slim` simplified; `register_confirm.slim` added
- [ ] Course / account services refactored to use Bearer
- [ ] `courses.rb` reads `auth_token` from session
- [ ] `account.rb` reads `auth_token` from session for system-role routes
- [ ] Tests updated / added
- [ ] Attendance: `RecordAttendance` + `ListEligibleEvents` services added; home + course-detail UI wired
- [ ] Manual smoke test through both repos in dev (incl. check-in flow)
- [ ] `rake spec` green
- [ ] `bundle exec rubocop .` green
- [ ] `bundle exec bundle-audit check --update` green
- [ ] Retrospective migration audit
- [ ] Squash to 2 payload commits
- [ ] Merge PR to `main` — deferred to user

## Key Findings

### Starting point

- `SecureMessage` lib already exists — same primitive `VerifyRegistration` needs for the registration token. The App already has the encryption library it needs; this branch is about *using it for a new purpose* (registration tokens, not session ciphertexts). No new lib file required.
- `SecureSession` already wraps the session with `set / get / delete` over `SecureMessage` ciphertexts. Adding `:auth_token` is one extra `set` call.
- `ApiClient` exists with `get / post / put / delete` and `authenticated_post / put / delete` helpers that merge `current_account_id` into the JSON body. After this branch, the `authenticated_*` helpers are gone — every method gains an optional `auth_token:` kwarg that translates to an `Authorization: Bearer <token>` header.
- All existing course / account services route through `ApiClient`, so the Bearer-token plumbing localizes to one file plus each service's call signature.
- `AuthenticateAccount` currently does `response.fetch('attributes').merge('include' => response['include'])` because the API's pre-branch response is `{type, attributes, include}` (a single account, no envelope). After this branch the response is `{type: 'authenticated_account', attributes: {account: <envelope>, auth_token: <string>}}` and the service returns `{account: account_hash, auth_token: token_string}`.
- `auth.rb` `POST /auth/register` currently calls `CreateAccount` directly (one-step registration). After this branch it calls `VerifyRegistration`; account creation moves to `account.rb` `POST /account/:token`.
- `config/secrets.example.yml` already has `APP_URL` and `API_URL`. No new env vars needed.

### Threat model delta

| Risk | Addressed here | Deferred |
| --- | --- | --- |
| API trusts whatever `current_account_id` the App sends in the request body | Replaced with API-issued encrypted `auth_token` carried in the `Authorization: Bearer` header | Granular server-side authorization rules (deferred per project rules) |
| Anyone could register an account for any email address | Email verification required: the user must click a link sent to that address before the account is created | Rate limiting / CAPTCHA (deferred) |
| Registration token tampering | `SimpleBox` (XSalsa20-Poly1305 AEAD) — forging a token requires the App's `MSG_KEY` | Registration token expiration (Q2) |

### Notes on the refactor

- **Raw-hash access continues.** The session keeps storing `current_account` as a raw hash; we add `:auth_token` as a separate session key. UI helpers (`admin?`, `course_creator?`, `role_for_course`) remain raw-hash readers, consistent with the existing pattern.
- **`ApiClient` Bearer plumbing.** Add `auth_token:` kwarg to each method (`get / post / put / delete`). When present, send `Authorization: Bearer <token>`. Drop the `authenticated_post / put / delete` helpers that smuggled `current_account_id` into the body.
- **Registration token expiration.** The registration token is long-lived this branch (matches the reference). A real fix would reuse the API-side token's expiration machinery — deferred per project rules.

## Questions

> Q1, Q2, … crossed off with decisions.

- [ ] **Q1 (ApiClient Bearer plumbing shape)**: pass `auth_token:` through every method call, or stash on `ApiClient` at construction? Default: pass through method calls — less stateful.
- [ ] **Q2 (registration token expiration)**: the registration token has no expiration this branch. Default: keep as-is; document as a known limitation.
- [ ] **Q3 (continue with raw-hash session storage?)**: default yes — no App-side data-model layer introduced this branch.
- [ ] **Q4 (`current_account['id']` reachability post-refactor)**: after every service drops `current_account_id`, audit whether anything (controllers, views) still reads `@current_account['id']` from the session-stored raw hash. Report findings in Post-Impl Notes so the API plan's matching question can be settled with evidence.

## Scope

**In scope — Payload 1 (token-based auth + registration verification)**:

- `VerifyRegistration` service (App-side)
- `AuthenticateAccount` updated to parse the new API envelope
- `ApiClient` updated to forward Bearer auth_token via kwarg; `authenticated_*` helpers removed
- `SecureSession` stores both `:current_account` and `:auth_token`
- `auth.rb`: split register into two-step flow; add `GET /auth/register/:token`
- `account.rb`: add `POST /account/:token`; system-role routes refactored to forward `auth_token:`
- `register.slim` simplified; `register_confirm.slim` added
- All existing course / account services refactored to forward Bearer auth_token instead of `current_account_id` body field
- `courses.rb` and `account.rb` controllers read `auth_token` from session and pass to services
- Tests for `VerifyRegistration` and updated `AuthenticateAccount`

**In scope — Payload 2 (attendance check-in UI)**:

- `app/services/record_attendance.rb` (new): `ApiClient.post('/courses/:id/attendances', {event_id:}, auth_token:)`
- `app/services/list_eligible_events.rb` (new): `ApiClient.get('/attendances/eligible', auth_token:)`
- `student_in?(course_id, current_account)` helper on `App` controller — raw-hash reader mirroring `admin?` / `course_creator?`. Scans `current_account['include']['enrollments']` for `course_id == X` with `role == 'student'`.
- `app/controllers/app.rb` root route: when `@current_account` is set, fetch eligible events and pass them to `home.slim`.
- `app/controllers/courses.rb`: new `POST /courses/:id/attendances` route → `RecordAttendance` → flash + redirect to `/courses/:id`.
- `app/presentation/views/home.slim`: top block "Events you can check in to right now" (only when the list is non-empty), rendering one row per eligible event.
- `app/presentation/views/_eligible_event_card.slim` (new partial): course name + event name + time window + single Check-in submit button.
- Per-event row on `courses/show.slim`: conditional Check-in button vs "Attended ✓" badge, gated on `student_in?` + template-computed `live_now` + `my_attendance_id` from event payload.
- No automated test additions for attendance (App spec policy unchanged this branch — manual smoke test).

**Out of scope** (deferred per project rules — do not creep in):

- Any App-side data-model layer wrapping the API JSON envelope (raw-hash access continues)
- Replacing the existing UI helpers (`admin?`, `course_creator?`, `role_for_course`, new `student_in?`) with model methods
- Input-validation rules on form data
- Any visualization or location-capture widget beyond plain HTML forms
- Place-based attendance check (only the time-window half is consumed)
- Staff UI for viewing or overriding event attendance
- Registration-token expiration

## Security Concerns Addressed This Week

1. **Email verification gates account creation.** The user must demonstrate control of the email address (by clicking the verification URL) before a password can be set and an account materialized.
2. **Tokens as transferable proof of trust.** After login, the App carries an API-issued encrypted token; the API trusts requests that carry a valid token, not requests that carry a `current_account_id` body field.
3. **Two encryption layers wrapping the session.** The `auth_token` is encrypted by the API; the session value containing it is encrypted again by `SecureMessage` from the earlier session-hardening branch. Both must be broken for an attacker with cookie access to recover identity material.
4. **The App as a "deputy."** The App's session is the deputy's identity badge; encrypting it (already done) and limiting its capability via tokens (this branch) bounds what an attacker who steals the cookie can do.

## Tasks

> Check tasks off as soon as each one is finished — do not batch.

### Setup

- [ ] Branch `3-auth-token` created off `main`
- [ ] `CLAUDE.local.md` updated to point at this plan
- [ ] Plan-first commit (`docs: plan 3-auth-token`)

### Services

- [ ] `app/services/verify_registration.rb` (new): `SecureMessage.encrypt({email:, username:})` → URL-safe token; build `verification_url = "#{config.APP_URL}/auth/register/#{token}"`; POST to API `/auth/register` with `{email, username, verification_url}`. Errors: `VerificationError`, `ApiServerError`.
- [ ] `app/services/authenticate_account.rb`: parse new API envelope. `response['attributes']['account']` is the account hash with `include`; `response['attributes']['auth_token']` is the opaque string. Return `{ account: account_hash, auth_token: token_string }`.
- [ ] `app/services/create_account.rb`: confirm it still calls API `POST /accounts` (unauthenticated route on the API side). No signature change.

### ApiClient + session

- [ ] `app/services/api_client.rb`: each method (`get`, `post`, `put`, `delete`) accepts optional `auth_token:` kwarg. When present, send `Authorization: Bearer <token>`. Drop `authenticated_post / put / delete` (callers switch to passing `auth_token:`).
- [ ] No change to `app/lib/secure_session.rb` — existing `set / get / delete` already supports the second key.

### Controllers

- [ ] `app/controllers/auth.rb`:
  - `POST /auth/login`: after `AuthenticateAccount.call`, store both `:current_account` and `:auth_token` in `SecureSession`.
  - `POST /auth/register`: switch to calling `VerifyRegistration`; flash "Check your email for a verification link"; redirect home (or `/auth/login`).
  - Add `GET /auth/register/:registration_token`: `new_account = SecureMessage.new(registration_token).decrypt`; render `register_confirm` with `new_account` and `registration_token` locals.
  - `GET /auth/logout`: delete both `:current_account` and `:auth_token` from session.
- [ ] `app/controllers/account.rb`:
  - Add `POST /account/:registration_token`: validate `password == password_confirm` (non-empty); decrypt token; call `CreateAccount.new(...).call(email:, username:, password:)`; redirect to `/auth/login` with success flash; on `CreateAccount::InvalidAccount`, redirect back to `/auth/register` with error.
  - Existing system-role routes: read `auth_token = SecureSession.new(session).get(:auth_token)`; pass `auth_token:` to `AssignSystemRole` / `RevokeSystemRole`.
- [ ] `app/controllers/courses.rb`: read `auth_token = SecureSession.new(session).get(:auth_token)` once at the top of the route block; pass `auth_token:` to every service call. Drop the `current_account_id = @current_account['id']` line and the `current_account_id:` kwargs.

### Views

- [ ] `app/presentation/views/register.slim`: remove the password input. Keep email + username only. Form posts to `POST /auth/register`.
- [ ] `app/presentation/views/register_confirm.slim` (new): show decrypted email + username (read-only display); password + password_confirm inputs; submit posts to `POST /account/:registration_token`.

### Service refactor — forward Bearer everywhere

For each of the following services, drop `current_account_id` from the call signature and accept / forward `auth_token:` to `ApiClient`:

- [ ] `list_courses.rb`
- [ ] `get_course.rb`
- [ ] `create_course.rb`
- [ ] `create_event_for_course.rb`
- [ ] `create_location_for_course.rb`
- [ ] `enroll_account_in_course.rb`
- [ ] `remove_enrollment.rb`
- [ ] `get_account.rb`
- [ ] `assign_system_role.rb`
- [ ] `revoke_system_role.rb`

### Tests

- [ ] Update `spec/integration/service_authenticate_spec.rb`: stub API to return the new envelope; assert the service returns `{account:, auth_token:}`.
- [ ] Add `spec/integration/service_verify_registration_spec.rb`: WebMock the API `/auth/register`; assert HAPPY 202 → service returns parsed JSON, SAD 400 → raises `VerificationError`, BAD network → raises `ApiServerError`.
- [ ] Update `spec/integration/service_create_account_spec.rb` if its signature changed.

### Attendance (Payload 2)

- [ ] `app/services/record_attendance.rb` (new)
- [ ] `app/services/list_eligible_events.rb` (new)
- [ ] `app/controllers/app.rb`: add `student_in?(course_id, current_account)` helper; root route fetches `eligible_events` when logged in.
- [ ] `app/controllers/courses.rb`: `POST /courses/:id/attendances` route.
- [ ] `app/presentation/views/_eligible_event_card.slim` (new).
- [ ] `app/presentation/views/home.slim` — top "eligible right now" block (skip when empty).
- [ ] `app/presentation/views/_event_row.slim` (or equivalent in `courses/show.slim`) — Check-in button vs Attended-badge gating.

### Manual verify

- [ ] API (`tyto2026-api`) running on port 3000 with `6-auth-token` checked out; App on 9292 with this branch.
- [ ] Register a new account: form submit → email lands → click link → password form → submit → redirect to login → log in → see courses.
- [ ] Log out → session cleared → cannot view `/courses` until logged in again.
- [ ] Seed a course where the test user is enrolled as `student`, plus an event whose window covers `Time.now`. Log in → home page shows the event under "Events you can check in to right now" → click Check in → flash success → home block disappears (no longer eligible) → course detail page shows "Attended ✓" for the event.
- [ ] As a teaching-staff user, curl `GET /api/v1/courses/:id/attendances/:event_id` → see all students' attendance rows for the event.

### Verify (automated)

- [ ] `bundle exec rake spec` green
- [ ] `bundle exec rubocop .` green
- [ ] `bundle exec bundle-audit check --update` green
- [ ] Code review
- [ ] Retrospective migration audit
- [ ] Squash / split into 2 payload commits
- [ ] Merge PR to `main` — deferred to user, done manually later in the week after class
- [ ] Skill self-reflection

## Commit strategy

- **Required commit count**: 2 payload commits. Payload 1 mirrors the reference branch's shape (Bearer-forwarding + email verification flow). Payload 2 is the Tyto-domain attendance UI.
- **Final branch shape**:
  ```
  docs: plan 3-auth-token
  Registration verification and token-based authorization              ← payload 1
  Adds student attendance check-in with home-page eligible events      ← payload 2
  ```
- **Payload 1 subject**: `Registration verification and token-based authorization`.
- **Payload 2 subject**: `Adds student attendance check-in with home-page eligible events`. Body notes the raw-hash `student_in?` helper as consistent with the existing `admin?` / `course_creator?` pattern.

## Infrastructure setup (user-operated)

No new App-side cloud infrastructure this week. SendGrid is API-only. Local dev requires:

1. The API running locally with valid `SENDGRID_*` config and a working SendGrid sandbox account.
2. `MSG_KEY` already set in `config/secrets.yml` (from the previous secure-session branch).
3. `APP_URL` set to `http://localhost:9292` for dev (already in `secrets.example.yml`).

No new production env vars beyond what the previous secure-session branch already requires.

## Completed

(to be filled in during implementation)

## Post-Implementation Notes (for reviewer)

(to be filled in before handing off for review)

---

Last updated: 2026-05-12
