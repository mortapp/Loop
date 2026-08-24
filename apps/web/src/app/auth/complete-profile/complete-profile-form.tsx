"use client";

import { useActionState, useEffect, useState } from "react";
import { completeProfile, type CompleteProfileState } from "./actions";
import { createClient } from "@/lib/supabase/client";

type UsernameStatus = "idle" | "checking" | "available" | "taken" | "invalid";

const USERNAME_PATTERN = /^[a-z0-9_]{3,20}$/;

/** Pure, render-time classification -- no state involved -- so "idle"/
 * "invalid" never need a setState call inside the debounce effect below. */
function classifyUsername(candidate: string): "idle" | "invalid" | "checkable" {
  if (!candidate) return "idle";
  if (!USERNAME_PATTERN.test(candidate)) return "invalid";
  return "checkable";
}

export function CompleteProfileForm({
  suggestedName,
  suggestedUsername,
  next,
  email,
  requirePasswordSetup,
}: {
  suggestedName: string;
  suggestedUsername: string;
  next: string;
  email: string;
  requirePasswordSetup: boolean;
}) {
  const boundAction = completeProfile.bind(null, next);
  const [state, formAction, pending] = useActionState<CompleteProfileState, FormData>(
    boundAction,
    null,
  );

  const [username, setUsername] = useState(suggestedUsername);
  const candidate = username.trim().toLowerCase();
  const syncStatus = classifyUsername(candidate);

  // Only the async availability result for a checkable candidate lives in
  // state -- "idle"/"invalid" are derived above, at render time, so the
  // effect below never needs to setState synchronously in its body, only
  // from the debounced RPC callback.
  const [checkResult, setCheckResult] = useState<{ candidate: string; available: boolean } | null>(
    null,
  );

  useEffect(() => {
    if (syncStatus !== "checkable") return;

    const timer = setTimeout(() => {
      const supabase = createClient();
      supabase.rpc("is_username_available", { candidate }).then(({ data, error }) => {
        if (!error) setCheckResult({ candidate, available: Boolean(data) });
      });
    }, 400);

    return () => clearTimeout(timer);
  }, [candidate, syncStatus]);

  const usernameStatus: UsernameStatus =
    syncStatus === "idle"
      ? "idle"
      : syncStatus === "invalid"
        ? "invalid"
        : checkResult?.candidate === candidate
          ? checkResult.available
            ? "available"
            : "taken"
          : "checking";

  const usernameHint: Record<
    UsernameStatus,
    { text: string; tone: "muted" | "success" | "danger" } | null
  > = {
    idle: null,
    checking: { text: "Checking…", tone: "muted" },
    available: { text: "Available", tone: "success" },
    taken: { text: "Already taken", tone: "danger" },
    invalid: { text: "3-20 characters: lowercase letters, numbers, underscores", tone: "danger" },
  };
  const hint = usernameHint[usernameStatus];

  return (
    <div className="flex min-h-dvh items-center justify-center px-4 py-8">
      <form action={formAction} className="flex w-full max-w-sm flex-col gap-4">
        <div>
          <h1
            className="text-3xl text-[var(--color-text-primary)]"
            style={{ fontFamily: "var(--font-display)", fontWeight: 600 }}
          >
            Finish your account
          </h1>
          <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
            One private ledger, ready in one step.
          </p>
        </div>

        <div className="border-y border-[var(--color-border-subtle)] py-3">
          <p className="text-sm font-medium text-[var(--color-text-primary)]">{email}</p>
          <p className="mt-0.5 text-xs text-[var(--color-text-tertiary)]">Verified email</p>
        </div>

        <label className="flex flex-col gap-1.5">
          <span className="text-xs font-medium text-[var(--color-text-secondary)]">Name</span>
          <input
            name="displayName"
            required
            defaultValue={suggestedName}
            autoFocus
            className="rounded-[var(--radius-sm)] border border-[var(--color-border-subtle)] bg-[var(--color-bg-secondary)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]"
          />
        </label>

        <label className="flex flex-col gap-1.5">
          <span className="text-xs font-medium text-[var(--color-text-secondary)]">Username</span>
          <div className="flex items-center gap-2 rounded-[var(--radius-sm)] border border-[var(--color-border-subtle)] bg-[var(--color-bg-secondary)] px-3 py-2 focus-within:border-[var(--color-brand)]">
            <span className="text-sm text-[var(--color-text-tertiary)]">@</span>
            <input
              name="username"
              required
              value={username}
              onChange={(event) => setUsername(event.target.value.toLowerCase())}
              className="flex-1 bg-transparent text-sm text-[var(--color-text-primary)] outline-none"
            />
          </div>
          {hint ? (
            <span
              className={`text-xs ${
                hint.tone === "success"
                  ? "text-[var(--color-brand-text)]"
                  : hint.tone === "danger"
                    ? "text-[var(--color-danger-text)]"
                    : "text-[var(--color-text-tertiary)]"
              }`}
            >
              {hint.text}
            </span>
          ) : null}
        </label>

        {requirePasswordSetup ? (
          <>
            <label className="flex flex-col gap-1.5">
              <span className="text-xs font-medium text-[var(--color-text-secondary)]">
                Create password
              </span>
              <input
                name="password"
                type="password"
                required
                minLength={8}
                autoComplete="new-password"
                placeholder="••••••••"
                className="rounded-[var(--radius-sm)] border border-[var(--color-border-subtle)] bg-[var(--color-bg-secondary)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]"
              />
            </label>
            <label className="flex flex-col gap-1.5">
              <span className="text-xs font-medium text-[var(--color-text-secondary)]">
                Confirm password
              </span>
              <input
                name="confirmPassword"
                type="password"
                required
                minLength={8}
                autoComplete="new-password"
                placeholder="••••••••"
                className="rounded-[var(--radius-sm)] border border-[var(--color-border-subtle)] bg-[var(--color-bg-secondary)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]"
              />
            </label>
          </>
        ) : null}

        {state?.error ? (
          <p className="text-sm text-[var(--color-danger-text)]" role="alert">
            {state.error}
          </p>
        ) : null}

        <button
          type="submit"
          disabled={pending || usernameStatus === "taken" || usernameStatus === "invalid"}
          className="mt-1 rounded-[var(--radius-sm)] bg-[var(--color-brand)] px-4 py-2.5 text-sm font-semibold text-[var(--color-on-accent)] transition-opacity hover:opacity-90 disabled:opacity-50"
        >
          {pending ? "Saving…" : "Finish setup"}
        </button>
      </form>
    </div>
  );
}
