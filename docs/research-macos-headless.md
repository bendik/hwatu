# Research: macOS headless automation, and whether hwatu should chase it

Status: strategy note, 2026-08-25. Written from probes run on this machine
(macOS 26.5.1, Apple Silicon) plus a competitor scan. It answers three
questions in order:

1. Is the macOS backend mechanically feasible on hwatu's terms?
2. Is anyone already winning this, and would hwatu have an edge?
3. If yes, what is the smallest build that earns the claim?

Everything in section 1 was measured, not assumed. The probe sources are
reproduced inline so they can be rerun.

## 1. Feasibility: measured, not argued

A plain `swiftc`-built CLI binary (no `.app` bundle, no code signature, no
Info.plist) drove `WKWebView` end to end.

| Probe | Result | Consequence for hwatu |
| --- | --- | --- |
| Offscreen `WKWebView` in a borderless `NSWindow` at (-10000,-10000), `NSApplication.activationPolicy = .prohibited` | loads, evals JS, `takeSnapshot` returns real pixels | headless-equivalent works with **no dock icon and no focus steal**, matching the "invisible until needed" principle |
| Cold snapshot, 1024x768 logical | 28-38 ms, 2048x1536 actual pixels (2x backing scale honored) | comparable to WebKitGTK cold capture; retina backing store is free |
| Warm snapshot on a loaded view | **2 ms** | the warm-service architecture transfers |
| Warm `evaluateJavaScript` round trip | **<1 ms** | in-process, no CDP hop |
| Warm nav + load, example.com over the network | 337 ms | network-bound, same as any engine |
| 8 concurrent views on one shared `WKProcessPool`, all loading | 555 ms total | parallel agents are viable in one daemon |
| Process launch to first snapshot, whole binary | ~610 ms cold | one-time engine init, then warm |
| `env -i` (stripped environment) | works | no DISPLAY-equivalent env dependency |
| Cookie written by process A, read by process B via `WKWebsiteDataStore.default()` | persisted, `example.com/hwatu_probe` visible | profile/session persistence has a native equivalent |
| WAAPI seek: `getAnimations()`, `pause()`, `currentTime = 1000`, snapshot | `matrix(1,0,0,1,150,0)` at t=1000 on a 2s/300px linear keyframe, and the two PNGs differ | **hwatu's deterministic animation-seek verification renders correctly offscreen** |

### The one hard constraint, and why it happens to be fine

`requestAnimationFrame` **does not tick** in an offscreen window:

- `orderBack(nil)` at (-10000,-10000): **1 frame per second**
- `orderFrontRegardless()` still offscreen: **0 frames per second**
- transparent non-activating `NSPanel` at desktop window level, onscreen:
  still **1 frame per second**

A naive port that waits on rAF-driven page readiness will hang. One probe
did hang, for exactly this reason. This is not a bug to work around; it is
WebKit's occlusion/display-link throttling and it is not negotiable from
outside.

It matters less than it looks, because hwatu already decided not to measure
motion by watching it. `verify::seek` freezes animation time and screenshots
a chosen instant; `verify::motion` reads the animation inventory as numbers
from WAAPI and CSSOM. Both are pure JS and CSSOM operations that require no
frames to be presented. The probe confirms seek renders the sought state
offscreen on WKWebView. **hwatu's verification model is unusually
well-suited to macOS offscreen rendering, and a Playwright-style
"screenshot the running animation" model is not.** That is a real, specific,
defensible edge rather than a slogan.

Rules this imposes on the macOS backend:

- Never gate readiness on rAF, `document.timeline` advancing, or any
  frame-count heuristic. Use load/DOM/network settle plus explicit seek.
- Report a capability such as `motion.realtime: degraded` rather than
  silently returning frozen numbers.
- Smooth-scroll and shortform work (the human-side `smoothwheel.rs`,
  1775 lines of it) is only meaningful in a **visible** window on macOS.
  Visible windows tick normally; that split is the natural product seam.

### Constraints still open

- **Needs a GUI session.** `launchctl asuser 0` failed outright. A pure
  SSH/CI macOS runner with no logged-in Aqua session is unproven and likely
  blocked. Headless CI on macOS should be scoped out of M1 and stated
  honestly, not implied.
- **Notarization.** The CLI probe ran unsigned, but distribution to other
  people needs Developer ID signing, notarization, and stapling. Budget it
  as real work, not a checkbox.
- **`takeSnapshot` is viewport-only.** Full-document capture needs an
  explicit resize-and-restore or tiled scroll strategy; WebKitGTK's
  `SnapshotRegion::FullDocument` has no direct peer.

## 2. Competition: the space is loud, the native-macOS corner is empty

Star counts, fetched 2026-08-25:

| Project | Stars | Shape |
| --- | --- | --- |
| browser-use | 110,536 | LLM agent loop over Playwright |
| ChromeDevTools/chrome-devtools-mcp | 49,720 | first-party CDP MCP |
| microsoft/playwright-mcp | 36,474 | first-party Playwright MCP |
| lightpanda-io/browser | 34,251 | from-scratch headless engine, no macOS |
| browser-tools-mcp | 7,298 | extension-based |
| **hwatu** | **78** | warm native daemon + verification instrument |
| onorbumbum/aslan-browser | 16 | WKWebView + Unix socket + JSON-RPC, a11y-tree-first, **last pushed 2026-02**, effectively dormant |
| LockInTime/headless | 0 | WKWebView on macOS, Chromium on Linux, one CLI, actively developed |

Two readings, and they point the same way.

**The generic "native macOS browser for agents" idea is taken and it is not
working.** Aslan is architecturally almost identical to what a hwatu macOS
backend would be (WKWebView, hidden `NSWindow` so JS keeps running, Unix
socket, NDJSON, sub-2 ms eval, ~15 ms screenshot) and it has 16 stars and
six months of silence. LockInTime/headless is the same bet, better executed
and more security-conscious, with zero stars. Both lead with "not Chrome,
no 500 MB download, fewer tokens." That pitch has been run twice and
converted nobody. **Do not ship "hwatu now runs on macOS" as the headline.**
It is a commodity claim with two dead comparables.

**What none of them sell is measurement.** Aslan and headless both stop at
observe-and-act: a11y tree, click, fill, screenshot. Neither has a pixel
diff score, an animation inventory, deterministic seek, a baseline with
region significance gating, or a convergence number an agent can climb.
Playwright has visual comparison but it belongs to the test runner, not the
agent, and it answers pass/fail rather than 97.49%. hwatu's `verify.rs`,
`snapdiff.rs`, `verify_job.rs`, and `clone.rs` (roughly 5,400 lines) are the
part of the codebase with no equivalent anywhere in the scan.

**The second unmatched asset is focus-preserving hand-off.** Aslan hides a
window; headless has a startup-presentation setting. Neither promises that
a live session moves between invisible agent work and a real human window
without losing cookies, navigation, or in-progress form state. On macOS, the
probe shows this is buildable: `.prohibited` activation policy means agent
work genuinely cannot steal focus, and promoting the same `WKWebView` to a
visible window is an ordinary AppKit operation.

Last night's failure on this very machine is the market evidence. An agent
spent hours fighting Safari AX trees, 2x-versus-points coordinate bugs, a
crates.io `s` hotkey stealing keystrokes into the search bar, keystrokes
landing in the wrong app, and a Touch ID prompt that refused synthetic
clicks. That is the status quo for a macOS agent that needs a logged-in
browser, and it is terrible. The hwatu answer to that specific pain is not
"another automation API," it is: a persistent profile the agent owns, plus
a hand-off that materializes the exact session when a human factor (Touch
ID, captcha, a password) is genuinely required.

## 3. Verdict and the smallest build that earns it

**Build it, but do not build it as a port.** Two-thirds of `hwatud` is GTK
and WebKitGTK plumbing; `window.rs` alone has 197 GTK references across
3,438 lines, and `automation.rs` another 56 across 3,612. A faithful port
is many thousands of lines to arrive at parity with a project that has
zero stars.

The asymmetry to exploit: hwatu's differentiated code, the verification
math and job/baseline machinery, is the code that touches GTK **least**.
`verify.rs` has 11 native references in 1,211 lines; `snapdiff.rs` has
none. The instrument is nearly portable already.

### Recommended sequencing

**M1: the instrument, not the browser.** Ship a macOS binary that does
exactly one thing: `hwatu check <url>` and `hwatu diff` against a baseline,
on an offscreen `WKWebView`, one call, warm, focusless. Deliberately ship
without tabs, keybinds, smooth scrolling, ad blocking, or the human shell.
Declare `motion.realtime` degraded and `capture.full_document` limited.
This is roughly the backend seam plus the capture path, and it puts the one
capability nobody else has onto the platform where the paying users
actually sit. Every measurement above says it will work.

**M2: hand-off.** Promote a live session from invisible to a real window
without replacing it, and back. This is the answer to last night's Safari
disaster and the only feature in the portfolio that no competitor claims.

**M3: honest CI story or an explicit no.** Determine whether a GUI-less
macOS runner can host `WKWebView`. If not, say so in the README instead of
letting people discover it in a GitHub Actions log.

**Not now:** the tiling-WM browser on macOS. There are no tiling WMs to
serve, rAF throttling makes the scrolling work meaningless offscreen, and
the human-side value proposition does not transfer. macOS is a
verification-only platform until proven otherwise.

### Positioning, concretely

Not "hwatu runs on macOS now." That claim is worth 16 stars, measured.

The claim worth making is: **your agent can prove a macOS page is right,
in one warm call, without touching your keyboard, and hand you the live
session when it hits Touch ID.** The measurement is the product; the
native engine is just how it stays fast and invisible.
