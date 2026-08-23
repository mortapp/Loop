-- PostgreSQL executes triggers with the same timing and event alphabetically.
-- Keep account-integrity checks ahead of lifecycle validation so legacy direct
-- writes retain the established cross-account SQLSTATE contract, while the
-- lifecycle guards still validate same-account state and relationship rules.

alter trigger purchases_guard_lifecycle on public.purchases
  rename to purchases_validate_lifecycle;

alter trigger listings_guard_lifecycle on public.listings
  rename to listings_validate_lifecycle;

alter trigger sales_guard_lifecycle on public.sales
  rename to sales_validate_lifecycle;

alter trigger returns_guard_lifecycle on public.returns
  rename to returns_validate_lifecycle;
