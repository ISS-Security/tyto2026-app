# 5-account-api-token — Display the read-only API key on account details

> **IMPORTANT**: This plan must be kept up-to-date at all times. Assume context can be cleared at any time — this file is the single source of truth for the current state of this work. Update this plan before and after task and subtask implementations.

## Branch

`5-account-api-token` — branched off the `4-validation` tip (not `main`,
which is still behind). The follow-on Google sign-in branch will build on
this branch's tip.

## Goal

Show the logged-in user their **API access key** (a read-only-scoped auth
token) on their own account-details page, behind a collapsible "show key"
control, so they can hand it to a deputy/3rd-party tool that should only
*read* their data. This is the App-side payoff of the API's scope work:
`GET /api/v1/accounts/[username]` now returns an authorized-account
envelope carrying a freshly minted **read-only** token, distinct from the
full-power session token.

Adapted from the project's reference App at the corresponding branch.

## Dependency (hard)

The read-only key exists only once the API's scope branch makes the
account endpoint return `{ data: { attributes: { account: …, auth_token:
<read-only token> } } }`. Implement/finalize that API branch first; until
then this branch can scaffold the view but cannot show a real key.

## Current State

- [ ] Plan created
- [ ] Branch created
- [ ] Service reads `auth_token` from the new envelope
- [ ] `Account` parser exposes the read-only key for self
- [ ] `account.slim` "API Access" collapsible section (self only)
- [ ] `style.css` tweak
- [ ] Tests + fixtures
- [ ] rubocop / audit
- [ ] Code review + retrospective audit
- [ ] Squash to required commit count
- [ ] Merge PR to `main` — deferred to user, after class

## Key Findings

### Starting point

- `account.rb` already has a self-vs-admin `GET /account/[username]`:
  self renders `@current_account` directly; admin uses `GetAccount` +
  `Account.from_api`.
- The `Account` parser already carries `auth_token` — but that's the
  **full** session token, not what we want to display. The point is to
  surface a **reduced read-only** key, so we fetch it from the API
  account endpoint rather than reusing the session token.
- `account.slim` shows Username / Email / System roles / Course roles;
  add an "API Access" block (self only) with a collapsible reveal + a
  "(read-only key, valid 1 month)" note.

### Threat model delta vs the previous branch

| Risk | Addressed here | Deferred |
| --- | --- | --- |
| User hands out a full-power key to a 3rd party | Surface a read-only key instead | Key rotation/revocation UI |
| Admin viewing another user could copy a usable key | API-Access block shown for self only | — |

### Domain scope (this branch only)

- Changed: account self-view fetches + displays a read-only key; minor CSS.
- No new models/routes beyond the read-only-key plumbing.

## Questions

- [x] **Q1. (Resolved 2026-05-27.)** Extend `GetAccount` + `Account.from_api`
  to read the authorized-account envelope (`data.attributes.account` +
  `data.attributes.auth_token`) so self + admin views share one path. No
  new thin service.
- [x] **Q2. (Resolved 2026-05-27.)** Show the key for **self only** (gate
  on `is_self`); never when an admin views another user.
- [x] **Q3. (Resolved 2026-05-27.)** Self-view now calls the account
  endpoint (extra request accepted) to fetch the read-only key.

## Scope

**In scope**: fetch + display the read-only API key on the self
account-details page; collapsible reveal; minor CSS; tests.

**Out of scope** (deferred per project rules):

- Google sign-in button / callback (the follow-on branch).
- Key rotation/revocation UI.
- Showing keys for other users.

## Tasks

### Service / model
- [ ] 1. `GetAccount` (or new thin service) reads the read-only `auth_token` from the authorized-account envelope (Q1).
- [ ] 2. `Account` parser exposes the read-only key for the self envelope.

### Controller
- [ ] 3. `account.rb` — self-view fetches the read-only key (Q3); admin view stays key-less (Q2).

### View / assets
- [ ] 4. `account.slim` — "API Access" collapsible block (self only) + read-only note.
- [ ] 5. `style.css` — collapse/spacing tweak.

### Tests
- [ ] 6. Service spec parses the read-only token from the envelope.
- [ ] 7. Integration: self sees the key; admin viewing another user does not.
- [ ] 8. Fixtures updated for the authorized-account envelope.

### Verify
- [ ] 9. `bundle exec rubocop .`
- [ ] 10. `bundle audit check --update`
- [ ] 11. Code review
- [ ] 12. Retrospective migration audit
- [ ] 13. Squash to required commit count
- [ ] 14. Merge PR to `main` — deferred to user

## Commit strategy

- **Required payload count**: **1** (matches the reference branch).
- **Subject (verbatim)**: `Displays API auth token in account details`.
- Plan commit (`docs: plan 5-account-api-token`) not counted.

## Completed

(to be filled in during implementation)

## Post-Implementation Notes (for reviewer)

(to be filled in before review)

---

Last updated: 2026-05-27
