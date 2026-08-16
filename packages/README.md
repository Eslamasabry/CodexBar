# Shared packages

Platform-neutral contracts, fixtures, and render-independent presentation models belong here as the cross-platform
work grows. They must be free of AppKit, terminal escape sequences, Android APIs, and provider credential access.

The existing `Sources/CodexBarCore` remains the canonical provider-fetching and normalisation package.
