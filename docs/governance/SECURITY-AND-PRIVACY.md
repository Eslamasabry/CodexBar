---
summary: "Security and privacy baseline for local provider usage tracking."
read_when:
  - "Handling credentials, browser state, diagnostics, logging, or pairing"
---

# Security and privacy baseline

## Data classification

| Class | Examples | Rule |
| --- | --- | --- |
| Capability secret | OAuth token, API key, browser session/cookie | Never log, render, sync, or place in test fixtures; use the platform secret store or restrictive local file permissions |
| Sensitive metadata | email, organisation/workspace/account IDs, plan | Keep local; redact by default in diagnostics and screenshots |
| Usage snapshot | quotas, reset time, balance, source, freshness | Store only when needed for the requested feature; show its source and age |
| Aggregate diagnostic | adapter/version/error category | Redact before export; include no raw response, headers, paths, or identities |

## Required controls

- Prefer official API, CLI, local RPC, or OAuth sources. Browser-cookie access is explicit opt-in and a last resort.
- Bind local APIs to loopback or a Unix socket. Remote access and Android pairing require a separately reviewed,
  mutually authenticated transport; do not expose `serve` beyond localhost.
- Minimise retention. Delete raw provider responses after parsing; keep only the normalised data needed for the user
  feature and explain how to clear it.
- Keep diagnostics fail-closed: if redaction cannot be guaranteed, do not export.
- Treat provider adapter changes as supply-chain-sensitive: use scrubbed fixtures, pin dependencies, and report parser
  schema mismatches without including payloads.
- Never execute provider-returned content or shell commands, and never include untrusted text in terminal escape
  sequences without sanitising it.

## Incident response

For suspected credential exposure: stop the affected source, invalidate/revoke the credential with its provider,
remove local caches, document the exposure boundary, and publish a remediation note. Do not ask users to share tokens,
cookies, raw browser databases, or unredacted diagnostic exports in issues.
