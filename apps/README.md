# Apps

Product surfaces live here without disturbing the upstream Swift package at the repository root.

| Surface | Responsibility | Credential policy |
| --- | --- | --- |
| `tui/` | Interactive terminal presentation over CodexBar's provider pipeline | Reads no credentials directly |
| `linux/` | Future native Linux shell integrations and packaging | Reads only local CLI/contract output |
| `android/` | Future paired Android application and widget | Never receives provider credentials |

An app may own presentation, accessibility, local settings, and pairing state. It may not add a duplicate provider
fetcher, scrape a browser, or reinterpret a provider's quota response.

See `docs/monorepo/README.md` before adding a new app.
