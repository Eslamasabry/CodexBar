---
summary: "Short epics for the upstream-friendly Linux-first roadmap."
read_when:
  - "Planning cross-platform CodexBar work"
---

# Cross-platform epics

1. **Upstream-compatible foundation** — Keep the Swift package stable, establish monorepo boundaries, and document
   design, privacy, security, and contributor rules before new product surfaces land.
2. **All-provider terminal dashboard** — Add an interactive `codexbar tui` over the existing registry with provider
   comparison, account-aware detail, source/freshness, refresh, and partial-failure handling.
3. **Portable presentation contract** — Extract a versioned, render-independent snapshot only when the TUI and a
   second surface need it; retain CLI/JSON compatibility throughout.
4. **Linux glance surfaces** — Add a Waybar reference integration, then evaluate GNOME/KDE consumers, all as thin
   views over the core/CLI contract.
5. **Android companion discovery** — Define secure pairing, widget freshness, alert policy, accessibility, and offline
   behaviour before adding Android code or any remote transport.
6. **Provider resilience and trust** — Improve source diagnostics, parser fixtures, stale/error UX, and safe redacted
   support bundles across every existing provider.
