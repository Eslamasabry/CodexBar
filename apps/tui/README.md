# Terminal UI

The terminal UI is the first cross-platform product surface. It is an interactive view over the existing CodexBar CLI
provider registry, not a second usage tracker.

It must work over SSH, retain useful output in ordinary non-interactive terminals, and make provider source,
freshness, reset timing, and partial failures visible.

## Interaction model

The home screen is an adaptive bento grid: each enabled provider/account gets a tile, and every provider-authentic
quota lane returned by Core remains visible in that tile. At narrow widths the grid collapses to a compact single
column without inventing or dropping quota values. `Enter` opens a focused detail view; arrows move the grid or
scroll detail, `j`/`k` move through accounts, `r` refreshes, and `f` focuses one provider.

The capacity cue is read-only guidance over fresh reported headroom and reset times. It never ranks model quality,
combines unlike quota types into a synthetic total, or suggests account rotation or limit avoidance.
