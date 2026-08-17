# LOOP Domain Model

This is the map from product concepts (CLAUDE.md, docs/ROADMAP.md) to the
actual schema in `supabase/migrations/`. When the two disagree, the
migrations are the source of truth — update this doc to match, not the
other way around.

## Identity and account context

Every signed-in person has a `profile` (1:1 with `auth.users`). A profile
can act through one or more `account`s:

- Every profile gets exactly one **personal account**, created
  automatically on signup.
- A profile can additionally belong to any number of **business
  accounts**, via `business_members` rows on a `business`.

`account_id` is the single foreign key that every domain table below
carries. Access control lives in one function,
`public.has_account_access(account_id)`, so MAKE/PROTECT/RECOVER never
reimplement authorization — they just point at an account. This is what
"both mode" (docs/ROADMAP.md Phase 2) means in practice: a person is
never locked into one context, they switch which account they're acting
as.

## Shared core primitives

These are not specific to any engine — MAKE, PROTECT, and RECOVER all
read and write them:

| Table | Purpose |
|---|---|
| `contacts` | People/companies you deal with (customers, vendors, buyers). |
| `items` | The OWN anchor entity. A physical thing you bought, are quoting, or are reselling. |
| `documents` | Files (receipts, invoices, warranties, listing screenshots) attached to an item or any other row via `related_type`/`related_id`. |
| `money_events` | Append-only value ledger. Every dollar earned, spent, refunded, or recovered gets a row. This is what "money/value primitives" in CLAUDE.md refers to. |
| `actions` | The unified task queue. Powers the Today engine (docs/ROADMAP.md Phase 3). |
| `events` | Append-only domain event log. Powers the Today feed and future automations/AI. |

## The lifecycle, in tables

```
EARN            BUY                 OWN         RETURN / RESELL          EARN AGAIN
  |               |                  |                 |                     |
MAKE          PROTECT             items          PROTECT / RECOVER      money_events
leads →     purchases →      (the anchor)      returns, warranties         (kind =
opportunities   ↓                  ↑            valuations, listings,     'recovered')
  → quotes   warranties ----------/              sales
```

- **MAKE** (`leads`, `opportunities`, `quotes`, `quote_line_items`) — turns
  a contact into revenue. A won quote is expected to produce a
  `money_events` row (`kind = 'earn'`).
- **PROTECT** (`purchases`, `returns`, `warranties`) — guards an owned
  item. A purchase records what was bought and its return/warranty
  windows; a return or warranty claim is expected to produce a
  `money_events` row (`kind = 'refund'`).
- **RECOVER** (`valuations`, `listings`, `sales`) — turns an owned item
  back into cash. A sale is expected to produce a `money_events` row
  (`kind = 'recovered'`).

`items.status` (`owned` → `returned` / `listed` → `sold` / `disposed`)
tracks where an item sits in that lifecycle at a glance.

## Conventions

- Money is always integer cents (`*_cents` columns), never floating point.
- `money_events` and `events` are append-only: insert and select only, no
  update/delete policies or grants. They are the audit trail; corrections
  are new rows, not edits.
- Every mutable table has `created_at`/`updated_at` maintained by
  `public.set_updated_at()`.
- `packages/contracts` mirrors every table here as a zod schema — keep
  both in sync when the schema changes.
