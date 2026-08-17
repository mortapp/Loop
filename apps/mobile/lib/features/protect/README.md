# PROTECT (ReturnGuard)

Strongly-typed domain extension for the **PROTECT** engine: purchases,
returns, and warranties.

This folder is intentionally empty of implementation for now. It exists so
the module boundary is established up front — PROTECT-specific screens,
models, and providers land here, built on top of the shared core
primitives in `lib/core/` (identity, account context, businesses,
contacts, items, documents, actions, events, money/value primitives).

The `lib/features/today/` unified action feed and `lib/features/money/`
value view are expected to surface PROTECT data once this domain
extension is built out, rather than PROTECT having its own separate
navigation surface.
