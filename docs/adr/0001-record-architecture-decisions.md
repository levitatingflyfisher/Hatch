# 0001 — Record architecture decisions

**Status:** Accepted · 2026-08-06

## Context

Hatch encodes contested territory: pedagogy research with live debates
(timed practice, retrieval effects), game-design ethics (engagement vs. dark
patterns), and two first-in-fleet technology choices. A maintainer who cannot
see *why* a choice was made will re-litigate it, and some of these choices look
wrong until you've read the evidence.

## Decision

Keep Nygard-style ADRs in `docs/adr/`, indexed in its README. Any decision a
future maintainer would plausibly reopen gets one. Superseding adds a pointer;
it never edits the superseded record.

## Consequences

The decision log is the second-highest documentation authority in the repo
(after the tests). Cheap to write now, expensive to reconstruct later.
