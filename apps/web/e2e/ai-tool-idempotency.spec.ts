import { expect, test } from "@playwright/test";
import type { SupabaseClient } from "@supabase/supabase-js";
import { executeTool } from "../src/lib/ai/tools";

type StoredRow = Record<string, unknown>;

function fakeSupabase() {
  const rows: Record<string, StoredRow[]> = { actions: [], money_events: [] };
  const client = {
    from(table: string) {
      return {
        async insert(row: StoredRow) {
          const idField = table === "actions" ? "related_id" : "source_id";
          const duplicate = rows[table].some(
            (existing) =>
              existing.account_id === row.account_id && existing[idField] === row[idField],
          );
          if (duplicate) return { error: { code: "23505", message: "duplicate" } };
          rows[table].push(row);
          return { error: null };
        },
        select() {
          const filters: StoredRow = {};
          const query = {
            eq(field: string, value: unknown) {
              filters[field] = value;
              return query;
            },
            async maybeSingle() {
              const data = rows[table].find((row) =>
                Object.entries(filters).every(([field, value]) => row[field] === value),
              );
              return { data: data ?? null, error: null };
            },
          };
          return query;
        },
      };
    },
  } as unknown as SupabaseClient;
  return { client, rows };
}

test("an approved Today action executes exactly once across an exact retry", async () => {
  const { client, rows } = fakeSupabase();
  const args = [
    client,
    "account-a",
    "user-a",
    "create_action",
    { title: "Follow up" },
    "11111111-1111-4111-8111-111111111111",
  ] as const;

  expect(await executeTool(...args)).toEqual({ summary: 'Added "Follow up" to Today.' });
  expect(await executeTool(...args)).toEqual({ summary: 'Added "Follow up" to Today.' });
  expect(rows.actions).toHaveLength(1);
});

test("an approved money event executes exactly once across an exact retry", async () => {
  const { client, rows } = fakeSupabase();
  const args = [
    client,
    "account-a",
    "user-a",
    "log_money_event",
    { kind: "earn", amountDollars: 25, description: "Fixture" },
    "22222222-2222-4222-8222-222222222222",
  ] as const;

  expect(await executeTool(...args)).toEqual({ summary: "Logged earn of $25.00." });
  expect(await executeTool(...args)).toEqual({ summary: "Logged earn of $25.00." });
  expect(rows.money_events).toHaveLength(1);
});
