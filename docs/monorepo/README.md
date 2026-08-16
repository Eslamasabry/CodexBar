---
summary: "Cross-platform repository boundaries and delivery rules."
read_when:
  - "Adding a Linux, Android, or terminal surface"
  - "Deciding where new cross-platform code belongs"
---

# Monorepo structure

CodexBar remains an upstream-compatible Swift package at the repository root. The monorepo grows around it rather
than relocating it.

```text
Sources/ and Tests/       Existing Swift provider core, macOS app, widgets, and CLI
apps/                     Product surfaces: tui, linux, android
packages/                 Future platform-neutral contracts and fixtures
integrations/             Thin desktop/shell consumers
docs/design/              Shared visual and interaction system
docs/governance/          Ethics, privacy, and security decisions
docs/epics/               Product roadmap for refinement
```

## Dependency direction

```text
CodexBarCore/provider registry -> CodexBarCLI/versioned local output -> apps/integrations
```

Dependencies must only flow to the right. Apps and integrations never import provider credentials, parse provider
payloads, or fetch provider endpoints directly. A future shared contract is extracted only after two surfaces need it;
do not create an abstraction before there is a real consumer.

## Contribution strategy

- Keep core/CLI changes small, independently testable, and suitable for an upstream pull request.
- Keep Android and compositor-specific code isolated until CodexBar maintainers agree to own it.
- Add a design note before a new transport, credential store, background service, telemetry mechanism, or platform
  permission.
- Every new surface must show source/freshness/error state and obey the governance documents.
