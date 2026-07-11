---
summary: "Ethics and product boundaries for a local AI-provider usage tracker."
read_when:
  - "Adding a provider, notification, pairing flow, analytics, or automation"
  - "Reviewing data collection or a feature that could evade provider limits"
---

# Ethics charter

## Purpose

CodexBar helps people understand the limits and cost signals already assigned to their own accounts. It must increase
agency and transparency, not extract data, manipulate attention, or help circumvent provider policy.

## Non-negotiable commitments

1. **User control over data.** Process usage data locally by default. Do not sell, train on, or share usage history,
   account metadata, prompts, projects, or credentials.
2. **Consent before access.** Explain what a permission, local file, cookie, OAuth token, API key, or pairing link is
   needed for. Make each source independently revocable.
3. **No limit evasion.** Do not rotate accounts, automate sign-ups, disguise account identity, defeat throttling, or
   route users around a provider's subscription/fair-use limits.
4. **No surveillance.** Do not read prompt content, terminal scrollback, shell history, window titles, repository
   contents, clipboard, or browsing activity to infer usage or provider identity.
5. **Honest uncertainty.** Mark estimates, stale results, unavailable fields, and undocumented-source data. Never
   present a locally calculated cost or token count as an authoritative subscription limit.
6. **Calm attention.** Notifications are opt-in, rate-limited, and designed for resets or user-chosen risk thresholds;
   no dark patterns, shame, streaks, or consumption-maximising mechanics.
7. **Accessible by default.** Every risk state has text and non-color representation; keyboard, screen-reader, and
   narrow-terminal use are supported for the surfaces that claim to support them.

## Review gates

A maintainer must explicitly review any change that adds a network destination, system permission, credential type,
background service, telemetry, analytics SDK, notification category, pairing flow, or provider source based on an
undocumented endpoint. The review records the user benefit, data accessed, retention, failure mode, and removal path.

If a feature cannot meet these commitments, it does not ship.
