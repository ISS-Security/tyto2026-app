# 6-signed-protected — Request signing, CSP/security headers + admin members page

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.
>
> **FINAL RELEASE**: This is the last feature branch. After it merges, the app is feature-locked — security updates only. Out-of-scope items are permanently out.

## Branch

`6-signed-protected`

## Goal

Two browser/client trust layers. (1) **Request signing**: every non-authenticated API call (create account, register, authenticate, SSO) is Ed25519-signed with the app's private `SIGNING_KEY` so the API can verify the body came from this app, untampered. (2) **Browser security headers**: `secure_headers` middleware emits cookie hardening (Secure/HttpOnly/SameSite), frame/sniff/referrer protections, and a strict Content-Security-Policy with a violation-reporting endpoint — plus the view refactors needed to *survive* a strict CSP (externalized map JS, no inline styles).

Third slice: an **admin Members page** (`GET /admin/accounts`) — nav item visible only to admins, listing every account with system-role badges and filter/sort controls, each row linking to the existing `/account/[username]` management page. Consumes the API's new admin accounts index.

## Strategy: Vertical Slice

1. `SignedMessage` lib + config wiring + signing in the four pre-login services + spec updates (commit 1)
2. CSP-compliance view refactor (externalize inline JS, de-inline styles), then `security.rb` with secure_headers config + violation endpoint (commit 2)
3. Admin members page: service → controller → view → nav gate (commit 3)

## Current State

- [x] Plan created
- [x] Branch created off `main`
- [x] Commit 1: SignedMessage + signed services + specs
- [x] Commit 2: JS externalization + security.rb + CSP + session-cookie hardening
- [x] Commit 3: admin members page
- [x] Live smoke (2026-06-04, CSP enforced): credential login, both map widgets, geofenced check-in round trip, members page filters/sorts — zero CSP violations. Google SSO not yet live-smoked (needs a real Google login — do once before merge).
- [x] Code review — reviewed and approved 2026-06-04
- [x] Commits shaped to required count (3 payloads)
- [ ] Merge PR to `main` — deferred to user, done manually later in the week after class

## Key Findings

### Starting point — already in place (no work needed)

- `rake url:integrity` task; SRI hashes on every CDN asset (Bootswatch/Popper/Bootstrap in `layout.slim`, Leaflet in `_maps_loader.slim`).
- `.logo` CSS class; `flash.now` render-in-place login failure; controllers `require_relative 'app'`; `.rubocop.yml` HashSyntax config.
- Login page uses an inline Google SVG — no Font Awesome / bootstrap-social CDNs to allowlist.
- Production SSL via Roda `redirect_http_to_https` + `hsts` plugins in `config/environments.rb` — `security.rb` must **not** add another SSL enforcer; reference the existing plugins in a comment.
- `Account` parser model already has `admin?`; `_role_badge.slim` exists — the members page reuses both.
- `ApiClient#get` already supports `params:` (query-string) — `ListAccounts` needs no client changes.

### CSP landmines (this app's specific risks)

- **4 views with inline `javascript:` blocks**: `_maps_loader.slim`, `_checkin_geolocate.slim`, `_attendance_map.slim`, `courses/locations/new.slim`. A strict `script_src` without `'unsafe-inline'` silently breaks all maps + geo check-in. **Decision: externalize** these into JS asset files served from `'self'`; page-specific data (coords, OSM constants) moves to `data-*` attributes read by the external scripts.
- **4 views with inline `style=` attributes**: `_attendance_map.slim`, `_event_row.slim`, `_eligible_event_card.slim`, `courses/locations/new.slim` → move to `style.css` / Bootstrap utility classes.
- **CSP source inventory**:
  - `style_src`: `'self'`, bootswatch.com, cdn.jsdelivr.net, unpkg.com (Leaflet CSS)
  - `script_src`: `'self'`, cdn.jsdelivr.net (Popper/Bootstrap), unpkg.com (Leaflet)
  - `img_src`: `'self'`, tile.openstreetmap.org, unpkg.com (Leaflet marker images), \*.googleusercontent.com (SSO avatars), `data:`
  - `font_src`: `'self'` (verify in DevTools during smoke)
  - `report_uri`: `/security/report_csp_violation`
- Services call the API through `ApiClient`; signing wraps at the call site (`@api.post('/accounts', SignedMessage.sign(account))`) keeping `ApiClient` generic.
- WebMock stubs in four service specs assert exact POST bodies — all must switch to signed bodies.
- Session middleware: add `httponly: true, same_site: :lax` to the active `Rack::Session::Pool`, to the production `Rack::Session::Redis`, **and to both commented-out variants** (the commented alternatives are kept deliberately — update them in place, do not delete).
- `secure_headers` gem is actively maintained (7.3.0, 2026-06-03) — safe dependency.

### Threat model delta

| Risk | Addressed here | Out |
| --- | --- | --- |
| Tampering with pre-login API requests | Ed25519 signing of all non-authenticated calls | Replay protection |
| XSS via injected scripts | CSP script allowlist with **no** `'unsafe-inline'` (made honest by the externalization) | — |
| Clickjacking / framing | `X-Frame-Options: DENY`, `frame_ancestors 'none'` | — |
| Cookie theft / cross-site request riding | Secure + HttpOnly + SameSite=Lax session cookie | Per-form CSRF tokens |
| CDN asset substitution | (SRI already shipped) CSP adds source allowlisting | — |
| Silent policy breakage | Violation report endpoint + logging | — |
| Admins blind to account inventory | Members page | — |

### Domain scope (this branch only)

No new domain entities; the members page renders existing `Account` model lists.

## Questions

- [x] Q1. `secure: true` cookies over `http://localhost` in dev → originally **keep unconditional**; **smoke falsified this** (2026-06-04): rack-session refuses server-side to *commit* a Secure cookie over a non-TLS request (no Set-Cookie at all — it is not a browser localhost exemption), killing dev logins. Resolved per the planned fallback: dev/test sessions get `httponly + same_site: :lax` only; the production Redis session adds `secure: true`. The secure_headers `config.cookies` `secure: true` stays unconditional (it governs cookies set inside the middleware stack).
- [x] Q2. External map JS delivery → **Roda `assets` plugin js group** (decided 2026-06-04): files in `app/presentation/assets/js/` (sibling of `css/`), registered in `plugin :assets`, emitted with `== assets(:js)`; separate js group for map files so non-map pages don't load them (preserves the `@load_maps` conditional). Served from `'self'` — no CSP exception needed.
- [x] Q3. `?role=none` filter semantics → **convention fixed at plan time** (2026-06-04): `none` is a reserved filter token, not a role name — the API treats `?role=none` as "accounts with zero system-role assignments". This app sends the literal string; the API never looks it up as a role. Residual: live cross-check at task 20.

## Scope

**In scope**: `SignedMessage` + setup; signing in `create_account` / `verify_registration` / `authenticate_account` / `authorize_google_account`; `secure_headers` + `app/controllers/security.rb` (headers, CSP, `/security/report_csp_violation`); session-cookie hardening; CSP-compliance view refactor; admin members page (`ListAccounts` service, `admin.rb` controller, index view, nav gate); spec updates + new lib/service specs.

**Out of scope** (feature set is final — permanently out):

- Per-form CSRF tokens (`route_csrf`)
- CSP nonces; Reporting-API (`report-to`) migration
- Admin write actions on the members page (grant/revoke stays on `/account/[username]`)
- Rate limiting on the CSP report endpoint

## Security Concerns Addressed This Week

1. **Authenticating ourselves to the API** — pre-login requests are signed; only this app's `SIGNING_KEY` produces requests the API accepts.
2. **XSS** — CSP script allowlist; our own inline scripts are removed rather than allowlisted, so the policy actually protects.
3. **Confused-deputy browser / CSRF surface** — SameSite=Lax cookies cut cross-site cookie attachment.
4. **Security headers** — frame denial, MIME-sniff protection, referrer policy, cookie flags.
5. **CSP violation reporting** — the browser POSTs violations to `/security/report_csp_violation`; we log them.
6. **Subresource integrity** — already shipped (SRI hashes); CSP source allowlists complement it.

## Tasks

> Check tasks off as soon as each one is finished — do not batch.

### Commit 1 — sign non-authenticated requests

- [x] 1. `Gemfile` — add `gem 'secure_headers'` (used in commit 2; added here so one `bundle install` covers the branch) → `Gemfile.lock`.
- [x] 2. `app/lib/signed_message.rb` — `Tyto::SignedMessage`: `KeypairError`, `.setup(signing_key64)`, `.sign(message)` → `{ data:, signature: }` (Ed25519, Base64-strict).
- [x] 3. `config/environments.rb` — `SignedMessage.setup(ENV.delete('SIGNING_KEY'))` beside `SecureMessage.setup`.
- [x] 4. `config/secrets.example.yml` — `SIGNING_KEY` placeholder in all three envs. Key topology (decided 2026-06-04): dev → signing half of the dev keypair shared with the API (which holds only the verify half); test → this app's own throwaway test key (WebMock compares bodies; it need not match the API's test keypair); production → the production signing key exists **only** in this app's config — the API gets just the verify half, so it can never forge our signatures.
- [x] 5. ~~USER ACTION~~ *(delegated to AI 2026-06-04)*: dev — take the `SIGNING_KEY` half of the dev keypair generated on the API (`rake newkey:signing` there) into local `config/secrets.yml`; test — any throwaway signing key; production — generate the prod keypair at deploy time, `SIGNING_KEY` → Heroku config var here, `VERIFY_KEY` → the API. Nothing committed.
- [x] 6. Sign at the four pre-login call sites: `create_account.rb`, `verify_registration.rb`, `authenticate_account.rb`, `authorize_google_account.rb` (signs the `{id_token:}` body).
- [x] 7. Specs — switch WebMock body stubs to signed bodies in `service_create_account_spec.rb`, `service_verify_registration_spec.rb`, `service_authenticate_spec.rb`, `service_authorize_google_account_spec.rb`; add `spec/lib/signed_message_spec.rb` (output shape; signature verifies against the matching verify key; `KeypairError` on bad setup).

### Commit 2 — CSP and security headers

#### CSP-compliance view refactor (precondition)

- [x] 8. Externalize the 4 inline `javascript:` blocks to asset-served JS (per Q2: `app/presentation/assets/js/`, Roda `assets` plugin js group(s), `== assets(:js)` in layout — map-specific group keeps the `@load_maps` conditional): maps-loader globals + Leaflet-unavailable fallback, check-in geolocate handler, attendance-map init, location-placement init. Page data via `data-*` attributes.
- [x] 9. De-inline `style=` attrs in `_attendance_map.slim`, `_event_row.slim`, `_eligible_event_card.slim`, `courses/locations/new.slim` → `style.css` / utility classes.
- [x] 10. Manual dev run: maps + check-in still work pre-CSP.

#### secure_headers

- [x] 11. `app/controllers/security.rb` — `use SecureHeaders::Middleware`; cookies `{secure: true, httponly: true, samesite: {lax: true}}`; `x_frame_options 'DENY'`, `x_content_type_options 'nosniff'`, `x_xss_protection '1'`, `x_permitted_cross_domain_policies 'none'`, `referrer_policy 'origin-when-cross-origin'`; CSP per the source inventory above with `report_uri /security/report_csp_violation`; `route('security')` POST handler logging via `App.logger.warn`. Keep a commented `# use Rack::Protection, reaction: :drop_session` alternative. SSL enforcement stays in `environments.rb` (Roda plugins) — comment points there.
- [x] 12. `config/environments.rb` — `httponly: true, same_site: :lax` on the active Pool session, the production Redis session, and both commented variants.
- [x] 13. Rubocop pass; add targeted disables only where genuinely required.

#### Smoke

- [x] 14. Full dev pass with CSP enforced: credential login, register, Google SSO (avatar renders), course pages, location-placement map, geo check-in, OSM tiles. Console: zero violations. Then deliberately trigger one violation to demo the report endpoint.

### Commit 3 — admin members page

- [x] 15. `app/services/list_accounts.rb` — `ApiClient.get('/accounts', params: {role:, sort:}.compact, auth_token:)` → list of `Account` models.
- [x] 16. `app/controllers/admin.rb` — `GET /admin/accounts`: `require_login!`; non-admin → flash error + redirect home; forwards `role`/`sort` params.
- [x] 17. View `admin/accounts/index.slim` — table of username + role badges (`_role_badge`); filter (admin/creator/member/none) and sort (username/role) controls that re-GET with query params; rows link to `/account/[username]`; empty state.
- [x] 18. `nav.slim` — "Members" item gated by `@current_account.admin?`.
- [x] 19. `spec/integration/service_list_accounts_spec.rb` — WebMock: happy list, param forwarding, 403 → `ApiError`.
- [x] 20. Cross-check against the live local API branch for envelope shape (`include.system_roles`).

### Verify

- [x] `bundle exec rake spec`
- [x] `bundle exec rubocop .`
- [x] `bundle exec bundle-audit check --update`
- [x] Code review
- [x] Retrospective migration audit: diff-level, full-tree, and shared-file content diff against the reference branch — reconcile every difference
- [x] Squash / split into required commit count
- [ ] Merge PR to `main` — deferred to user, done manually later in the week after class
- [x] Skill self-reflection: re-read `/week-plan` SKILL.md and propose refinements if the week surfaced any gaps

## Commit strategy

- **Required payload count**: **3**
  1. `Sign non-authenticated requests to API` — tasks 1–7.
  2. `Configure browser-side CSPs and security headers` — tasks 8–14 (body notes the JS-externalization precondition).
  3. `feat: add admin members page with role filter and sort` — tasks 15–20.
- The plan commit (`docs: plan 6-signed-protected`) does not count.

## Completed

- 2026-06-04 — Commit 1 (tasks 1–7), TDD red-green: `Tyto::SignedMessage`
  (sign + KeypairError; unit spec covers round-trip verify, tamper
  rejection, deterministic signatures — the WebMock stubs rely on Ed25519
  determinism to pre-compute exact signed bodies); the four pre-login
  services sign at their `ApiClient.post` call sites; signed-shape stub
  updates across all four service specs (the register specs now read
  `body['data']['verification_url']` and assert a non-empty signature).
- 2026-06-04 — Commit 2 (tasks 8–14): inline JS externalized to
  `app/presentation/assets/js/` — **gotcha**: the Roda assets plugin maps
  js *group names to subdirectories*, so files live in `js/checkin/` and
  `js/maps/` (flat files 503'd; caught in smoke). `:checkin` group loads on
  every page, `:maps` only when `@load_maps`. Per-event data via `data-*`
  attributes; show/hide switched from `el.style.display` to
  `classList`/`d-none` (static `style=` attrs are CSP-blocked; CSSOM class
  toggles are not). `security.rb` written test-first
  (`spec/integration/security_headers_spec.rb`: headers, strict CSP with no
  `'unsafe-inline'`, allowlists, report endpoint 200). The UUID
  regression guard was rewritten for the new wiring (the id now travels as
  a data-attribute, fixing the JS-quoting bug class structurally).
- 2026-06-04 — Commit 3 (tasks 15–20), TDD red-green: `ListAccounts`
  service (happy parse, param forwarding, params omitted when nil,
  403 → `ForbiddenError`); `admin.rb` (login gate → admin gate → service →
  view; errors flash + redirect home); `admin/accounts/index.slim`
  (GET-link filter button group + sort links, `_role_badge` reuse, empty
  state); nav "Members" item. Live cross-repo check against the local API:
  full list with badges, `?role=admin`, `?role=none` empty state,
  `?sort=username`, and the non-admin redirect all verified.
- 2026-06-04 — Style chores (repo convention, mirrored with the API):
  chained calls and method arguments both indent one step
  (`Layout/MultilineMethodCallIndentation: indented`,
  `Layout/ArgumentAlignment: with_fixed_indentation`); all sites
  autocorrected; the commented session variants reindented by hand.
- Verified: 99 runs / 198 assertions, 0 failures; rubocop clean (70
  files); bundle-audit clean.

## Post-Implementation Notes (for reviewer)

### Reference gaps found during smoke (fixed here, worth a look)

1. **CSP violation-report route returned an unsupported block result** in
   the reference implementation (`logger.warn`'s `true`), which 500s on
   every report — browsers ignore the response, so it went unnoticed. This
   app returns `''` → 200, pinned by spec.
2. **secure_headers' cookie config cannot flag the session cookie**: the
   session middleware is added during config load, so it sits *outside*
   `SecureHeaders::Middleware` and its `Set-Cookie` is never seen. Cookie
   flags are therefore set in the Rack session options themselves.
3. **Secure-cookie/dev interaction** (Q1): see the Questions section — the
   flag is production-only because rack-session won't commit Secure cookies
   over non-TLS requests.

### Other notes

- SSL enforcement deliberately stays with the Roda
  `redirect_http_to_https` + `hsts` plugins in `environments.rb` —
  `security.rb` carries a pointer comment instead of a second enforcer.
- Retrospective migration audit (2026-06-04): file lists reconcile against
  the reference branch; this app's extra slice (JS externalization: 4 asset
  files, 6 view edits, assets-plugin groups, map CSS classes) is the
  precondition for an honest no-`'unsafe-inline'` CSP — the reference app
  had no inline JS to externalize. No commented reference blocks removed.
- Not yet live-smoked: Google SSO login (needs a real Google account) —
  the signed `{id_token:}` path is spec-pinned; do one manual SSO login
  before merge. The dev DB carries a leftover smoke event ("CSP Smoke
  Session", course 5) — delete or reseed at will.
- `X-XSS-Protection: 1` is emitted for completeness; modern browsers
  ignore it (CSP is its successor).

---

Last updated: 2026-06-04 (finalized; remaining: one manual SSO login + PR + merge by the user)
