# 5-sso-auth — "Sign in with Google" via OAuth code → OIDC id_token

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`5-sso-auth` — branched off the `5-account-api-token` tip (`7cef084`), **not**
`main`. Builds against the API's `8-sso` `/auth/sso` endpoint.

## Goal

Add a "Sign in with Google" button to the login page and a `/auth/sso_callback`
route. The App runs the OAuth 2.0 **authorization-code** half of the flow:
sends the user to Google, receives a `code`, exchanges it (with the client id +
secret) at Google's token endpoint for tokens, and forwards the resulting OIDC
**`id_token`** to the API's `POST /auth/sso`. The API verifies the id_token
(against Google's JWKS) and returns a Tyto session token, stored in the
encrypted session like a normal login.

## Dependency on API `8-sso` (hard)

`POST /api/v1/auth/sso` must accept an **`id_token`** and verify it. The API
returns `{ data: { type: 'authorized_account', attributes: { account,
auth_token } } }` — the same envelope the account-detail endpoint uses, so the
service reuses that unwrap shape.

## Strategy

1. `AuthorizeGoogleAccount` — `call(code)` → POST Google token endpoint
   (client_id/secret/code/redirect_uri/grant_type, server-side) → extract
   `id_token` → POST `/auth/sso` `{ id_token }` via `ApiClient` → return
   `{ account, auth_token }`.
2. Controller: `google_oauth_url` builder (+ CSRF `state`) and a
   `/auth/sso_callback` GET that verifies `state`, calls the service, stores
   the session, redirects `/`.
3. "Sign in with Google" button on the login page.
4. Option A avatar: `Account#avatar` parser + a conditional `<img>` on the
   account page (no placeholder for password accounts).

## Current State

- [x] Plan created
- [x] Branch `5-sso-auth` created off `5-account-api-token` (`7cef084`)
- [x] `AuthorizeGoogleAccount` service (code → id_token → API /auth/sso) + spec
- [x] `google_oauth_url` helper + `/auth/sso_callback` route with `state` check
- [x] "Sign in with Google" button on login (inline Google "G" SVG)
- [x] `Account#avatar` parser + conditional avatar render on `account.slim`
- [x] Secrets example + secrets.yml (`GOOGLE_*` keys, all 3 envs)
- [x] Tests green (86 runs / 153 assertions / 0 fail) / rubocop (63) / audit clean
- [ ] Live smoke test (needs real Google client id + secret — WALKTHROUGH written)
- [ ] Code review + retrospective audit
- [ ] Merge PR to `main` — deferred to user

## Key decisions / divergences from the reference branch

- **GitHub → Google, access_token → id_token (OIDC).** The reference exchanged
  a GitHub `code` for an opaque access_token and forwarded that; here we forward
  the OIDC `id_token` the API verifies cryptographically.
- **CSRF `state` implemented** (random nonce in session, verified on callback).
  The reference had none. `nonce` is a documented future hardening (the API
  already binds the token via signature + `aud`/`exp`).
- **No `bootstrap-social` / Font Awesome.** This app loads neither, so the
  button uses an inline, brand-correct Google "G" SVG on a Bootstrap
  `.btn.btn-outline-dark` — no new CDN asset, no SRI to compute.
- **Option A avatar** — `Account#avatar` reader + a conditional `<img>` on the
  account page only (shown when the API serializes an `avatar`); password
  accounts render nothing. A small enhancement over the reference's login-only
  change.
- **`AuthenticateAccount` (App) unchanged** — Tyto already routed credential
  auth through `ApiClient` with its own error classes; the reference's
  config→ENV / rename edits don't apply.

## Tests

- `spec/integration/service_authorize_google_account_spec.rb` — WebMock Google
  token endpoint + API `/auth/sso`; happy path returns {account, auth_token};
  Google 4xx and API 401 both raise `UnauthorizedError`.
- `spec/models/account_spec.rb` — `avatar` reader (present / nil).
- `spec/regression_spec.rb` — lexical guards: login button + `google_oauth_url`,
  callback `state` verification, conditional avatar render. (No Rack::Test
  controller harness exists in this app — same constraint as week 13.)

## Commit strategy

- **Required payload count**: **1** (matches the reference branch).
- **Subject (verbatim)**: `Handles SSO login via OAuth`.
- Body: GitHub→Google + the id_token (OIDC) hand-off vs the reference's
  access_token.
- Plan commit (`docs: plan 5-sso-auth`) is scaffolding, not counted.

## Infrastructure setup (USER-OPERATED — Decision #12)

The App needs **both** `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` plus the
registered redirect URI `http://localhost:9292/auth/sso_callback` (dev). See
`WALKTHROUGH.google-oauth-setup.md` in the baby_tyto planning repo. Tests need
no real credentials (Google + API are mocked).

---

Last updated: 2026-05-28
