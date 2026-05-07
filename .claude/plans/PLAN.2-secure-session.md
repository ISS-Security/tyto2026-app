# 2-secure-session — Encrypted sessions, Redis store, simple registration

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after each task.

## Branch

`2-secure-session`

## Goal

Encrypt the contents of every session value with NaCl SecretBox layered **on top of** rack-session 2.x's existing AES-256-GCM cookie encryption, move the session store from in-memory to Redis (with an in-memory fallback for dev/test), add a simple registration form, and wire production HTTPS enforcement using Roda's native plugins.

The teaching beat is **cipher choice and misuse-resistance**, not "we're adding encryption" — rack-session 2.x already encrypts cookies with AES-256-GCM by default. What this branch adds is a second AEAD (XSalsa20-Poly1305) inside the cookie, with its own key, so a hypothetical CVE in either cipher (or its IV generator) doesn't expose session contents.

## Strategy: Vertical Slice

1. Add `MSG_KEY` to secrets (separate from `SESSION_SECRET` — the rack outer-layer key).
2. Build `SecureMessage` library — NaCl SimpleBox encrypt/decrypt with a Base64 wire format.
3. Build `SecureSession` library on top of `SecureMessage` — wraps any session-like Hash, plus a Redis wipe utility.
4. Wire `SecureMessage.setup` + `SecureSession.setup` from environment in `config/environments.rb`.
5. Switch the controllers to read/write session values through `SecureSession`.
6. Use `Rack::Session::Pool` for dev/test, `Rack::Session::Redis` for production. (The cookie session middleware from the previous branch goes away.)
7. Add Roda's native `redirect_http_to_https` + `hsts` plugins for production.
8. Add `CreateAccount` service + register view + register route.
9. Tighten error handling in `AuthenticateAccount` (distinguish 403 Unauthorized from other API errors).
10. Add `spec/spec_helper.rb` + WebMock-based integration specs.

## Current State

- [x] Plan created
- [ ] Branch created off `main`
- [ ] Gemfile additions (redis, redis-rack, redis-store, json, logger, webmock, minitest, minitest-rg)
- [ ] Procfile
- [ ] `config/secrets.example.yml` — `MSG_KEY`, `REDIS_URL`
- [ ] `app/lib/secure_message.rb`
- [ ] `app/lib/secure_session.rb`
- [ ] `config/environments.rb` rewrite (Pool dev/test, Redis prod, Roda HTTPS plugins, library setup)
- [ ] `app/controllers/app.rb` — session reads via SecureSession
- [ ] `app/controllers/auth.rb` — session writes via SecureSession; register routes; error type split
- [ ] `app/services/authenticate_account.rb` — `ApiServerError` class + branching
- [ ] `app/services/create_account.rb`
- [ ] `app/presentation/views/register.slim`
- [ ] `app/presentation/views/nav.slim` — register link enabled
- [ ] Rakefile — `generate:msg_key`, `session:wipe`, audit/release tasks
- [ ] `spec/spec_helper.rb`
- [ ] `spec/integration/service_authenticate_spec.rb`
- [ ] `spec/integration/service_create_account_spec.rb`
- [ ] `rake spec` green
- [ ] `bundle exec rubocop .` clean
- [ ] `bundle audit check --update` clean
- [ ] Browser smoke (login, inspect cookie, logout, register, login)
- [ ] Code review
- [ ] Retrospective migration audit
- [ ] Squashed / verified to required commit count
- [ ] Merge PR to `main` — deferred to user, manual, post-class

## Key Findings

### Starting point

`main` is at the merged `1-authenticated-sessions`. Already in place:

- Roda app skeleton with Slim, `Rack::Session::Cookie` keyed off `SESSION_SECRET`
- Login + logout flow, `AuthenticateAccount` service, `ApiClient` HTTP helper
- Controllers: `app.rb`, `auth.rb`, `account.rb`, `courses.rb`
- Slim views: login, home, account, courses index/show, layout, nav, flash_bar, partials
- `gem 'rbnacl', '~>7.1'`, `gem 'http', '~>5.1'`, `gem 'figaro', '~>1.2'`, `gem 'rack-session', '~>2.0'`
- Ruby 4.0.2 pinned
- `require_app` already includes the `lib` folder by default
- `Rakefile` already has `generate:session_secret` (rack outer key) and `url:integrity` (SRI helper)
- `.gitignore` has the partial-allowlist exception (`!app/presentation/views/_*.slim`) — already correct

Missing (this branch's job):

- `redis*` gems, testing gems (`minitest`, `minitest-rg`, `webmock`), `json`, `logger`
- `Procfile`
- `app/lib/secure_message.rb`, `app/lib/secure_session.rb`
- Production HTTPS enforcement
- Redis-backed session store (with Pool fallback for dev/test)
- `MSG_KEY` (NaCl inner-layer key) and Redis URL config
- Registration page + `CreateAccount` service
- `spec/spec_helper.rb` + integration specs
- Distinct error types in `AuthenticateAccount`

### Threat model delta vs previous branch

| Risk | Addressed here | Deferred |
|---|---|---|
| Session payload visible to anyone with cookie + rack secret | NaCl SecretBox layer means decrypting the rack cookie still leaves an encrypted blob. Two layers, two keys (`SESSION_SECRET` outer, `MSG_KEY` inner) — compromise of one doesn't compromise the other. | Key rotation policy / per-message HKDF |
| In-memory session pool doesn't scale or survive restarts | Redis store in production gives crash-tolerance + horizontal scaling | Redis-side encryption at rest |
| Plain HTTP credential traffic in production | Roda `redirect_http_to_https` + `hsts` plugins | n/a |
| Registration accepts arbitrary fields, no validation | Registration ships intentionally without validation — that's the cliffhanger for the next branch | next branch |
| Email verification | Not addressed | deferred per project rules |
| Session fixation (no rotation on login) | Not addressed | deferred per project rules |

### Domain scope (this branch only)

No new domain entities. The app continues passing the API JSON envelope around as raw hashes (with the existing `admin?` / `course_creator?` / `system_roles_of` helpers in `app/controllers/app.rb`); App-side parser models are deferred per project rules.

The registration POST builds a `{username, email, password}` payload and forwards to the API's `POST /api/v1/accounts` route (already wired in the API).

## Questions

> Crossed off as decisions are made.

- [x] **Q1. Payload commit subject — RESOLVED: `Secure sessions and simple registration`** (verbatim from the reference branch).
- [x] **Q2. Inner-cipher library shape — RESOLVED: single shared `SecureMessage`** reused for token encryption later. Document the reuse expectation in a one-line code comment.
- [x] **Q3. Inner-cipher key env-var name — RESOLVED: `MSG_KEY`** (mirror the reference). Justification: Redis is conceptually a message store; the same library will encrypt token messages later. The single key name reflects the single library's role across both purposes. `MSG_KEY` and `SESSION_SECRET` are intentionally distinct: `MSG_KEY` is the inner NaCl SecretBox key for `SecureMessage`; `SESSION_SECRET` is rack's outer AES-256-GCM cookie key.
- [x] **Q4. Redis env-var name — RESOLVED: support both.** `heroku-redis` (paid) exposes `REDIS_URL`; `rediscloud:30` (free) exposes `REDISCLOUD_URL`. Different deployers may end up on different tiers depending on which free-tier they've consumed. Code reads whichever is set: `@redis_url = ENV.delete('REDISCLOUD_URL') || ENV.delete('REDIS_URL')`. The `secrets.example.yml` shows both keys; uncomment the one matching your add-on. No code change when switching tiers.
- [x] **Q5. SSL enforcement plugin — RESOLVED: try Roda plugins first.** Use `plugin :redirect_http_to_https` + `plugin :hsts`. If either misbehaves with the installed rack-session/Roda versions, fall back to a small DIY redirect inside the production-only `configure` block.
- [x] **Q6. Payload commit count — RESOLVED: 1 (collapsed).** The reference history has 2 commits, but the second is a stale rack-session 2.x hash-notation fix that doesn't apply (this branch starts on rack-session 2.x natively). Note the collapse in the commit body and Post-Implementation Notes.
- [x] **Q7. Decode-the-cookie demo — RESOLVED: skip.** With rack-session 2.x already encrypting the outer cookie, the demo loses its original "look at this readable Hash dump" punch. The conceptual cipher-comparison lesson lands in lecture without the byte-level lab.
- [x] **Q8. App-side parser models — RESOLVED: no model.** Verified against the reference tree: no `app/models/` directory exists at this branch. Continue using raw-hash access for `current_account` and the existing helpers in `app/controllers/app.rb`. App-side parser models arrive in a later branch per project rules.

## Scope

**In scope:**

- `SecureMessage` + `SecureSession` libraries
- `MSG_KEY` env var (per Q3 — inner NaCl SecretBox key, distinct from rack's outer `SESSION_SECRET`; reused for token encryption later)
- Dual Redis env-var support: code reads `REDISCLOUD_URL` (Redis Cloud add-on) **or** `REDIS_URL` (Heroku Redis add-on), whichever is set
- Redis session store for production; `Rack::Session::Pool` fallback for dev/test
- Roda native HTTPS plugins for production
- `Procfile`
- Registration form + `CreateAccount` service + `routing.is 'register'` route
- `AuthenticateAccount` error type split
- `spec/spec_helper.rb` + integration specs (WebMock)

**Out of scope (deferred per project rules):**

- Form validation (entropy check, regex, length rules)
- Email verification + token-based authorization
- App-side parser models
- OAuth / Google sign-in
- Browser security headers (CSP, X-Frame-Options, etc.)
- CSRF token middleware

## Security Concerns Addressed This Week

(From the lecture deck for week 11.)

1. **Cipher choice and misuse-resistance.** Two AEADs in the same cookie path: rack's AES-256-GCM (96-bit IV, GHASH MAC, hardware-accelerated, **nonce-reuse-catastrophic**) wraps NaCl's XSalsa20-Poly1305 (192-bit nonce, polynomial MAC, designed for misuse-resistance). Choosing a primitive is choosing whose responsibility it is to use it correctly. NaCl was designed to take that responsibility off the caller.
2. **Defaults are not contracts.** Earlier rack-session versions were signed-only; the current line is AEAD; a future major could change again. Knowing the bytes lets you audit whether the library does what you think. Demo: `bundle show rack-session` → open `encryptor.rb` → point at `OpenSSL::Cipher.new('aes-256-gcm')`.
3. **Distributed session pool vs in-memory pool.** In-memory pools don't scale horizontally and don't survive process restart. Redis is shared, persistent (with config), and replicable. Pool is a fine dev/test choice; Redis is the production choice.
4. **Layered confidentiality.** If GCM ever has a critical CVE, the inner Poly1305 layer is unaffected — and vice versa. Cryptographic agility across algorithm families, not just keys.
5. **Production HTTPS enforcement.** Roda's `redirect_http_to_https` + `hsts` plugins set the browser-side policy (`Strict-Transport-Security: max-age=31536000`) so subsequent visits go straight to HTTPS without a round-trip.
6. **Simple registration is intentionally weak.** No validation, no email verification, no password rules. The deck calls out the gaps; subsequent branches close them.

## Tasks

### Setup

- [ ] 1. Verify `main` is clean. Confirm last commit on `main`.
- [ ] 2. Create branch `2-secure-session` off `main`.
- [ ] 3. Commit this plan: `docs: plan 2-secure-session`.

### Dependencies

- [ ] 4. Update `Gemfile`:
   - Add `gem 'redis', '~>5.0'`, `gem 'redis-rack'`, `gem 'redis-store'`.
   - Add `gem 'json'` and `gem 'logger', '~> 1.0'`.
   - Add `group :test do gem 'minitest'; gem 'minitest-rg'; gem 'webmock' end`.
- [ ] 5. `bundle install`.

### Procfile

- [ ] 6. Create `Procfile` with: `web: bundle exec puma -t 5:5 -p ${PORT:-9292} -e ${RACK_ENV:-development}`.

### Secrets config

- [ ] 7. Update `config/secrets.example.yml` and (locally) `config/secrets.yml`:
   - Add `MSG_KEY` (per Q3) to all three blocks. Generate via the new `rake generate:msg_key` task (added in step 16).
   - Add **both** `REDISCLOUD_URL` and `REDIS_URL` keys to all three blocks. Comment block in the file explains: "Set whichever your Redis add-on exposes. `rediscloud:30` (free tier) → `REDISCLOUD_URL`. `heroku-redis` (paid) → `REDIS_URL`. Code reads whichever is non-nil." Dev/test placeholders: `redis://localhost:6379/0`. Production: `<set by Heroku addon>`.
   - Confirm `config/secrets.yml` is gitignored.

### Library code

- [ ] 8. Add `app/lib/secure_message.rb`. Class methods: `setup(key)`, `generate_key`, `encrypt(message)` (returns a new `SecureMessage`). Instance methods: `to_s`, `decrypt`. Wire format: `Base64.urlsafe_encode64(NaCl SimpleBox ciphertext over JSON-encoded message)`.
- [ ] 9. Add `app/lib/secure_session.rb`. Class methods: `setup(redis_url)` (stores the URL for `wipe_redis_sessions`), `generate_secret` (delegates to `SecureMessage.encoded_random_bytes(64)`), `wipe_redis_sessions`. Instance methods: `initialize(session)`, `set(key, value)`, `get(key)` (returns `nil` if absent), `delete(key)`.

### Environments / sessions wiring

- [ ] 10. Rewrite `config/environments.rb`:
  - Add `require 'rack/session/redis'`.
  - Add `require_relative '../require_app'` and `require_app('lib')` so the libraries are loaded before `setup` is called.
  - Pull `MSG_KEY` via `ENV.delete('MSG_KEY')` and call `SecureMessage.setup(...)`. (`ENV.delete` is the established pattern in this codebase.)
  - Pull the Redis URL via `@redis_url = ENV.delete('REDISCLOUD_URL') || ENV.delete('REDIS_URL')` and call `SecureSession.setup(@redis_url)`. The fallback chain lets the same code support either Heroku Redis (`REDIS_URL`) or Redis Cloud (`REDISCLOUD_URL`) without modification.
  - Environment-gated session middleware. **Preserve the three-variant pedagogical structure**:
    - Dev/test: keep `Rack::Session::Cookie` commented out (the "previous approach" reference); make `Rack::Session::Pool, expire_after: ONE_MONTH` active; keep `Rack::Session::Redis` commented out (an "uncomment to test the production path locally" override).
    - Production: `Rack::Session::Redis, expire_after: ONE_MONTH, redis_server: @redis_url` active.
  - Add Roda HTTPS plugins inside `configure :production`: `plugin :redirect_http_to_https`; `plugin :hsts`. Replaces the older `Rack::SslEnforcer` middleware; note the swap in code comments.
  - Keep the existing `common_logger`, `LOGGER`, and `pry` blocks.

  **Comment preservation:** the commented-out variants above are deliberate teaching scaffolding — they show alternative session strategies in context. Do not delete them on style or dead-code grounds.
- [ ] 11. Confirm `require_app.rb` is unchanged.

### Controllers

- [ ] 12. Update `app/controllers/app.rb`:
   - Replace `@current_account = session[:current_account]` with `@current_account = SecureSession.new(session).get(:current_account)`.
   - Keep the existing `admin?` / `course_creator?` / `system_roles_of` / `roles_for_course` / `require_login!` helpers as-is.
- [ ] 13. Update `app/controllers/auth.rb`:
   - Login POST: replace `session[:current_account] = account` with `SecureSession.new(session).set(:current_account, account)`. Split the rescue into `rescue AuthenticateAccount::UnauthorizedError` (400 + flash error + re-render login) and `rescue AuthenticateAccount::ApiServerError` (500 + warn-log + redirect to login).
   - Logout GET: replace `session[:current_account] = nil` with `SecureSession.new(session).delete(:current_account)`.
   - Add `@register_route = '/auth/register'`. Add `routing.is 'register'` block: GET renders `:register`; POST calls `CreateAccount.new(App.config).call(**params)` and redirects to login on success, back to register with flash error on failure.

### Services

- [ ] 14. Update `app/services/authenticate_account.rb`:
   - Add `class ApiServerError < StandardError; end`.
   - In the `rescue ApiClient::ApiError` branch: raise `UnauthorizedError` for 403, `ApiServerError` for 5xx, re-raise otherwise.
- [ ] 15. Add `app/services/create_account.rb`:
   - `class CreateAccount; class InvalidAccount < StandardError; end; def initialize(config); @client = ApiClient.new(config); end; def call(email:, username:, password:); response = @client.post('/accounts', { email:, username:, password: }); rescue ApiClient::ApiError => e; raise InvalidAccount, e.message; end; end`.

### Rakefile

- [ ] 16. Update `Rakefile`:
   - Add `Rake::TestTask.new(:spec) { |t| t.pattern = 'spec/**/*_spec.rb'; t.warning = false }`.
   - Add `respec` (rerun-driven), `audit` (`bundle audit check --update`), `release` (`spec` + `style` + `audit`) tasks.
   - Add `task :load_lib do require_app('lib') end`.
   - Add `namespace :generate do desc 'Create NaCl key for SecureMessage'; task msg_key: [:load_lib] do puts "New MSG_KEY (base64): #{SecureMessage.generate_key}" end end` (matches the existing `generate:session_secret` namespace in the App's Rakefile and mirrors the reference branch).
   - Add `namespace :session do desc 'Wipe all sessions in Redis'; task wipe: [:load_lib] do … end end`.
   - Preserve existing `url:integrity` task.

### Views

- [ ] 17. Update `app/presentation/views/nav.slim`: replace the disabled register link (`a class="nav-link disabled" href='#' aria-disabled="true" register (coming soon)`) with `a class="nav-link" href='/auth/register' register`.
- [ ] 18. Add `app/presentation/views/register.slim`:
   - Bootstrap row/col layout, centered.
   - `form action='/auth/register' method='post'` with username, email, password fields.
   - Submit button styled with Bootstrap.
   - Verify the file is staged — the `_*` `.gitignore` rule allows partials via the existing exception, but `register.slim` is not a partial so it's not affected.

### Specs

- [ ] 19. Add `spec/spec_helper.rb`: sets `RACK_ENV=test`, requires `minitest/autorun` + `minitest/rg`, requires `test_load_all`, exposes `API_URL = app.config.API_URL`.
- [ ] 20. Add `spec/integration/service_authenticate_spec.rb` — happy + sad path with WebMock stubs against `#{API_URL}/auth/authenticate`.
- [ ] 21. Add `spec/integration/service_create_account_spec.rb` — happy (201), sad mass-assignment (400), sad API server error (5xx).

### Verify

- [ ] 22. `rake spec` — all green.
- [ ] 23. `bundle exec rubocop .` — clean.
- [ ] 24. `bundle exec bundle-audit check --update` — clean.
- [ ] 25. Browser smoke test: boot API + App, login, inspect the session cookie in DevTools (should be opaque base64), logout (cookie cleared / no `current_account`), register a new account, login as new account.
- [ ] 26. Code review.
- [ ] 27. Retrospective migration audit (diff-level, full-tree, shared-file content diff). Reconcile every difference. **Comment-block check:** every commented-out block in shared reference files (especially the three session-middleware variants in `config/environments.rb`) must be present in this branch with module/domain swaps. Removed reference comments are misses unless documented in Post-Implementation Notes with a deliberate reason.
- [ ] 28. Squash to the required payload-commit count.
- [ ] 29. Merge PR to `main` — deferred to user, manual, post-class.
- [ ] 30. Skill self-reflection — re-read the week-plan skill and propose refinements if any gap surfaced.

## Infrastructure setup (user-only — AI provides guidance, never executes)

> **Rule:** Cloud-infrastructure setup is the user's responsibility. The AI does **not** run `heroku create`, `heroku addons:create`, `heroku config:set`, `git push heroku`, `heroku run`, `heroku restart`, or any other command that creates, modifies, or pays for cloud resources. The AI documents what needs provisioning, explains trade-offs, and drafts copy-pastable commands; the user runs them.

The list below is reference material the user works from.

| Step | Notes |
|---|---|
| Create a separate Heroku app for the App (the API has its own Heroku app) | Two Heroku apps, two URLs. The App's deploy calls the API's URL. |
| Provision Redis: **either** `heroku addons:create rediscloud:30` (free — sets `REDISCLOUD_URL`) **or** `heroku addons:create heroku-redis:mini` (paid — sets `REDIS_URL`) | Whichever you have free-tier credit for. The code reads whichever env var is set, so no code change between tiers. |
| Set production env vars: `SESSION_SECRET`, `MSG_KEY`, `API_URL` (e.g. `https://<api-app>.herokuapp.com/api/v1`), `APP_URL` (e.g. `https://<app-app>.herokuapp.com`) | Generate fresh keys: `rake generate:session_secret` (existing) for the rack outer key, `rake generate:msg_key` (added this branch) for the NaCl inner key. **Do NOT reuse dev keys.** |
| `git push heroku main` | First deploy. |
| Open the App URL in a browser | Confirm 200 over HTTPS; HTTP request should redirect via Roda's `redirect_http_to_https` plugin. |
| (Optional, local) `brew install redis && brew services start redis` | Only if you want to test the Redis path locally. The default plan uses `Rack::Session::Pool` for dev/test, so this is a nice-to-have. |
| (Optional) `heroku run rake session:wipe` | Clears Redis-stored sessions. Useful when rotating `MSG_KEY`. |

**The user runs all of the above. The plan covers only the code changes that make them work; the AI never executes infrastructure commands.**

## Commit strategy

- **Required commit count**: 1 payload commit (per Q6 collapse, recommended). The `docs: plan 2-secure-session` commit (added in step 3) is scaffolding and does not count toward the payload total.
- **Grouping**: everything in scope folds into the single payload commit. If Q6 is overridden to keep two commits, split is `[library + wiring + controllers + services + views + specs + Procfile + Gemfile + Rakefile + secrets]` and a follow-up. Default = one commit.

## Completed

(filled in during implementation)

## Post-Implementation Notes (for reviewer)

(filled in before handoff)

---

Last updated: 2026-05-07
