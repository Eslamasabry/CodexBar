---
summary: "Portable design system derived from CodexBar's established provider presentation rules."
read_when:
  - "Designing a TUI, Linux panel, widget, or future Android companion"
  - "Changing quota, reset, freshness, failure, or provider presentation"
---

# CodexBar design system

## Product principle

**Make the next safe decision obvious at a glance.** A user should be able to see what is close to a limit, when it
recovers, whether the number is trustworthy, and what account/provider it describes without opening a dashboard or
guessing at a generic percentage.

This system preserves the established CodexBar approach: provider-specific data, compact glanceability, reset and
pace awareness, stable layout, and local-first privacy. It is a portable interpretation for the terminal, Linux, and
future Android—not an attempt to clone the macOS menu-bar implementation.

## Information model

### Truth hierarchy

Render this order whenever data exists:

1. **Provider and account** — provider name/icon, selected account label, and plan only when sourced by that provider.
2. **Quota window** — human label, remaining percentage by default, and a visual meter.
3. **Reset or detail** — reset countdown/absolute time, or a clearly labelled alternate detail when no reset exists.
4. **Pace** — reserve/deficit and estimated outcome only when timing data makes it meaningful.
5. **Source and freshness** — actual fetch strategy and last successful update; errors must never masquerade as fresh.
6. **Secondary signals** — credits, cost, provider health, storage, and model breakdowns after the limit information.

Never turn different signals into one total: subscription quota, API spend, local token estimate, context pressure, and
service health have different truth sources and meanings.

### Provider fidelity

- Treat each provider snapshot as a dynamic list of primary, secondary, tertiary, extra, or provider-specific lanes.
- Do not force a daily/monthly model onto 5-hour, weekly, rolling, model-specific, request-count, credit, or
  multimodal limits.
- Use provider-owned identity, plan, and account data only for that provider; never borrow it from another snapshot.
- A missing metric is absent, not zero. A failed refresh is an error/stale state, not a healthy empty card.

## Visual language

### Hierarchy and layout

- **Overview first, detail on demand.** Show all providers as compact comparable rows/cards; selecting one expands its
  full lanes and supporting data without changing the selected account or hiding peers.
- **Stable geometry.** Refreshes update values in place. Do not reorder cards, move controls, or replace rows with
  spinners while a request is active.
- **Dense but breathable.** Use a 4-point spacing rhythm: 4 within a datum, 8 within a metric group, 12 between groups,
  and 16 between provider cards. On a TUI, the equivalent is one blank line between groups and no decorative padding
  that hides an entire provider below the fold.
- **One action vocabulary.** Refresh, provider selection, account selection, detail, and quit/back must use the same
  labels and semantics across surfaces.

### Meter semantics

- A filled meter means **remaining quota** by default, matching the established CodexBar default. If a surface offers
  used quota, label it explicitly and flip the whole meter semantic; never mix both in one view.
- Pair every meter with a numeric percentage and text label. Color alone is never the status signal.
- Use a low-contrast track and one semantic fill. Provider branding may identify the card, but cannot encode risk.
- Critical, warning, healthy, stale, loading, and error are semantic states. Keep their text/icon equivalents visible
  in monochrome terminals and accessibility modes.

### Color and motion

- Use provider color for recognition sparingly: icon/accent, not the only meter state.
- Use green/teal for healthy headroom, amber for attention, red for imminent exhaustion or service failure, and muted
  neutral for unavailable/stale data. Respect terminal color capability and system high-contrast/reduced-motion
  settings.
- Motion is bounded and purposeful: a refresh indicator may animate while a request runs, but it must stop on timeout
  and must not cause continuous redraw or battery drain.

### Typography and copy

- Use plain, short labels: `5-hour`, `Weekly`, `Remaining`, `Resets in 43m`, `Updated 2m ago`, `Auth required`.
- Prefer a concrete timestamp/countdown over vague labels such as `soon` or `recently`.
- Explain an unusual provider metric in detail view rather than inventing a misleading generic name.
- Never shame users for consumption or frame quota exhaustion as a productivity failure.

## Interaction rules

- Preserve explicit user selection across refreshes, provider focus changes, and errors.
- Manual refresh coalesces repeated requests and gives immediate in-place feedback.
- Keyboard and screen-reader operation are first-class: visible shortcuts, predictable focus order, no mouse-only
  controls, and no essential hover-only information.
- Make error recovery actionable: identify the provider and source, distinguish authentication from timeout/unsupported
  states, and link to a safe diagnostic path without exposing secrets.
- Default notifications are quiet. Send threshold/reset alerts only after opt-in and deduplicate them per window.

## Surface adaptations

| Surface | Primary job | Required design behaviour |
| --- | --- | --- |
| TUI | Inspect, compare, and debug over a terminal/SSH session | Keyboard-first selection, visible source/freshness, non-interactive fallback, no persistent animation |
| Linux panel | Glanceable risk and fast entry to detail | One compact highest-risk signal, text backup for color, no credential access, no polling loop independent of core |
| Android widget | Glanceable paired status and reset awareness | Explicit desktop freshness/offline state, no provider login, taps open read-only detail |
| macOS menu | Existing reference surface | Preserve provider-specific cards, stable status-item identities, and in-place refresh behavior |

## Review checklist

Before approving a UI change, verify:

- The provider/account/source/freshness can be read without color or hover.
- Meter direction and percentage agree.
- Every displayed window is provider-authentic and dynamically rendered.
- Refresh/error/loading states do not destroy the prior useful layout.
- The screen remains useful in a narrow terminal, with large text, and without provider branding.
- The change adds no new sensitive-data collection, storage, or transmission.
