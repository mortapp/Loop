import assert from "node:assert/strict";
import test from "node:test";
import {
  MAX_MONEY_CENTS,
  isUuid,
  parseDollarsToCents,
  parseDollarValueToCents,
} from "./money-input.ts";

test("parses exact cent values without floating-point rounding", () => {
  assert.equal(parseDollarsToCents("12.34"), 1234);
  assert.equal(parseDollarsToCents("0.01"), 1);
  assert.equal(parseDollarsToCents("0", { allowZero: true }), 0);
  assert.equal(parseDollarsToCents("1000000000.00"), MAX_MONEY_CENTS);
});

test("rejects fractional cents, exponent notation, signs, and oversized values", () => {
  for (const value of ["1.005", "1e3", "+1", "-1", "NaN", "Infinity", "1000000000.01"]) {
    assert.equal(parseDollarsToCents(value), null, value);
  }
});

test("validates untrusted numeric tool values with the same bounds", () => {
  assert.equal(parseDollarValueToCents(49.99), 4999);
  assert.equal(parseDollarValueToCents(1.005), null);
  assert.equal(parseDollarValueToCents(Number.POSITIVE_INFINITY), null);
});

test("recognizes UUID request identities", () => {
  assert.equal(isUuid("b43dc4e2-8c81-4aac-86d9-e9b789c42e8d"), true);
  assert.equal(isUuid("not-a-uuid"), false);
});
