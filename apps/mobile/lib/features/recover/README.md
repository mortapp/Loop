# RECOVER (ResellLens)

Strongly-typed domain extension for the **RECOVER** engine: valuations,
listings, and sales.

This folder is intentionally empty of implementation for now. It exists so
the module boundary is established up front — RECOVER-specific screens,
models, and providers land here, built on top of the shared core
primitives in `lib/core/` (identity, account context, businesses,
contacts, items, documents, actions, events, money/value primitives).

The `lib/features/sell/` screen is the current RECOVER-facing surface and
is expected to be powered by this domain extension once it's built out.
