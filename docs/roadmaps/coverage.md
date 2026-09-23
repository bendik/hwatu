# Extension-bridge coverage (C1-C6)

Status: shipped 2026-09-22 (C1-C6 in two commits). This page records
the verb-by-verb audit of jcode's Firefox extension bridge against
hwatu's protocol, and what was built to close it. The constraint set:
**extensive coverage, complete headlessness**. Nothing here maps a
window or requests focus.

## Why

In-browser extension bridges (jcode's Firefox bridge is the audited
example: 33 background-script actions, `browser-agent-bridge.xpi`)
give agents a full-featured browser at the cost of stealing the
human's focus on every action and acting with the human's entire
logged-in blast radius. hwatu's position: an agent deserves its own
browser with its own credential stack, invisible by construction,
with hand-off reserved for genuinely human factors.

## Audit result

Of the bridge's 33 actions, 21 already had hwatu equivalents
(frequently stronger: ref-targeting, trusted input, watch-mode
expect, token-budgeted snapshots). The gaps became C1-C6:

| Tier | Verbs shipped | Bridge actions covered |
| --- | --- | --- |
| C1 frames | `list_frames` | listFrames (+ frame_id targeting via automatic same-origin traversal) |
| C2 content/forms | `get_content`, `fill_form` | getContent, fillForm |
| C3 speculation | `fork`, `list_forks` (+ `close`), `try_until` | fork, killFork, listForks, parallel, branch, tryUntil |
| C4 exploration | `scout` | scout, preexplore |
| C5 misc | `list_downloads`, `drop_file`, `auth_context` | listDownloads, dropFile, getAuthContext |
| C6 credentials | `fill_login` (password + TOTP) | secureAutoFill, and the 2FA half of requestAuth |

Remaining bridge actions map to existing verbs (navigate/reload/
evaluate/screenshot/scroll/click/type/waitFor/uploadFile/tab verbs →
window verbs/ping/batch) or to Handoff (requestAuth's human half).

## Design notes

- **Cross-origin frames are reported, not faked.** WebKitGTK's
  embedder API has no public cross-origin script entry. `list_frames`
  marks such frames `accessible: false` with their origin. Same-origin
  frames need no frame_id at all: every selector verb traverses
  accessible frame documents automatically.
- **Fork rides profiles.** A fork is an ordinary headless window on
  the source's profile (shared cookie jar) at the source's URL, with
  lineage recorded for `list_forks`. Killing a fork is `close`. This
  is strictly more parallel than tab duplication: forks are pooled,
  headless, and invisible.
- **`try_until` slices its deadline.** Each alternative gets
  `min(remaining, 2s)` so one hung selector cannot starve the rest.
  Allowed alternatives are deliberately tiny: click, type, expect.
- **`scout` is bounded everywhere:** depth ≤ 2, pages ≤ 10, per-page
  snapshot budget, same-host only, one warm window for the whole
  crawl, closed at the end.
- **`fill_login` never surfaces secrets.** Store lookup (pass/
  pass-otp/Bitwarden CLI) happens on a worker thread; the secret goes
  into page JS only; replies carry field names and counts, never
  values. TOTP means an agent profile enrolled once does 2FA headless
  forever.
- **`auth_context` reads names, not values.** Cookie names and
  storage keys are enough for "am I logged in?", and a
  `likely_authenticated` heuristic answers the common case in one
  token-cheap call.

## The one thing not replicated

Riding the human's live logged-in browser session. That is the
extension model's single structural advantage and hwatu rejects it
deliberately: the agent gets scoped standing (persistent named
profile + fill_login + its own accumulated session) instead of the
human's entire blast radius. The once-per-site cost of establishing
that standing is paid through `handoff` (queued, reason-tagged,
never focus-stealing).

## Deferred

- **WebAuthn virtual authenticator per profile** (software passkey):
  the strongest headless-auth move on the board, pending WebKitGTK
  exposing its automation-session virtual authenticator to embedders.
  Track upstream.
- **True cross-origin frame scripting**: requires upstream WebKitGTK
  API (WebKit has it internally for WebDriver). The capability report
  keeps agents from wasting cycles discovering the limit themselves.
