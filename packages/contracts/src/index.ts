/**
 * @loop/contracts
 *
 * Shared types and zod schemas for the LOOP data model, hand-mirrored from
 * `supabase/migrations/`. Table row schemas use snake_case to match what
 * the Supabase client returns verbatim; standalone value objects (see
 * money.ts) use camelCase since they are not raw DB rows.
 *
 * Keep this package in lockstep with the migrations: any column added,
 * renamed, or removed there should be reflected here in the same change.
 */

export * from "./money";
export * from "./identity";
export * from "./core";
export * from "./domains/make";
export * from "./domains/protect";
export * from "./domains/recover";
