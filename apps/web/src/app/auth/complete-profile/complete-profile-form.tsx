"use client";

import { useActionState, useEffect, useState } from "react";
import { completeProfile, type CompleteProfileState } from "./actions";
import { LoopSeal } from "@/components/ui/loop-seal";
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
  offerPasswordSetup,
}: {
  suggestedName: string;
  suggestedUsername: string;
  next: string;
  email: string;
  offerPasswordSetup: boolean;
}) {
  const boundAction = completeProfile.bind(null, next);
  const [state, formAction, pending] = useActionState<CompleteProfileState, FormData>(boundAction, null);

  const [username, setUsername] = useState(suggestedUsername);
  const candidate = username.trim().toLowerCase();
  const syncStatus = classifyUsername(candidate);

  // Only the async availability result for a checkable candidate lives in
  // state -- "idle"/"invalid" are derived above, at render time, so the
  // effect below never needs to setState synchronously in its body, only
  // from the debounced RPC callback.
  const [checkResult, setCheckResult] = useState<{ candidate: string; available: boolean } | null>(null);

  useEffect(() => {
    if (syncStatus !== "checkable") return;

    const timer = setTimeout(() => {
      const supabase = createClient();
      supabase
        .rpc("is_username_available", { candidate })
        .then(({ data, error }) => {
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

  const usernameHint: Record<UsernameStatus, { text: string; tone: "muted" | "success" | "danger" } | null> = {
    idle: null,
    checking: { text: "Checking…", tone: "muted" },
    available: { text: "Available", tone: "success" },
    taken: { text: "Already taken", tone: "danger" },
    invalid: { text: "3-20 characters: lowercase letters, numbers, underscores", tone: "danger" },
  };
  const hint = usernameHint[usernameStatus];

  return (
    <div className="flex min-h-dvh items-center justify-center px-4 py-8">
      <form
        action={formAction}
        className="flex w-full max-w-sm flex-col gap-4 rounded-[var(--radius-lg)] border border-[var(--color-border-subtle)] bg-[var(--color-surface)] p-6"
      >
        <div className="flex flex-col items-center gap-3 text-center">
          <LoopSeal size={32} />
          <p className="text-xs font-medium text-[var(--color-brand-text)]">✓ Verified</p>
          <h1 className="text-lg font-semibold text-[var(--color-text-primary)]">Welcome to LOOP</h1>
          <p className="text-sm text-[var(--color-text-secondary)]">Let&apos;s finish setting up your account.</p>
        </div>

        <label className="flex flex-col gap-1.5">
          <span className="text-[10px] font-semibold tracking-[0.15em] text-[var(--color-text-secondary)]">
            EMAIL
          </span>
          <input
            value={email}
            readOnly
            disabled
            className="rounded-[var(--radius-sm)] border border-[var(--color-border-subtle)] bg-[var(--color-bg-secondary)] px-3 py-2 text-sm text-[var(--color-text-tertiary)] outline-none"
          />
        </label>

        <label className="flex flex-col gap-1.5">
          <span className="text-[10px] font-semibold tracking-[0.15em] text-[var(--color-text-secondary)]">
            NAME
          </span>
          <input
            name="displayName"
            required
            defaultValue={suggestedName}
            autoFocus
            className="rounded-[var(--radius-sm)] border border-[var(--color-border-subtle)] bg-[var(--color-bg-secondary)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]"
          />
        </label>

        <label className="flex flex-col gap-1.5">
          <span className="text-[10px] font-semibold tracking-[0.15em] text-[var(--color-text-secondary)]">
            USERNAME
          </span>
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

        {offerPasswordSetup ? (
          <>
            <label className="flex flex-col gap-1.5">
              <span className="text-[10px] font-semibold tracking-[0.15em] text-[var(--color-text-secondary)]">
                PASSWORD <span className="text-[var(--color-text-tertiary)]">(optional -- to also sign in without Google)</span>
              </span>
              <input
                name="password"
                type="password"
                autoComplete="new-password"
                placeholder="••••••••"
                className="rounded-[var(--radius-sm)] border border-[var(--color-border-subtle)] bg-[var(--color-bg-secondary)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]"
              />
            </label>
            <label className="flex flex-col gap-1.5">
              <span className="text-[10px] font-semibold tracking-[0.15em] text-[var(--color-text-secondary)]">
                CONFIRM PASSWORD
              </span>
              <input
                name="confirmPassword"
                type="password"
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
          className="mt-1 rounded-[var(--radius-sm)] px-4 py-2.5 text-sm font-semibold tracking-wide text-[var(--color-on-accent)] transition-opacity disabled:opacity-50"
          style={{ background: "linear-gradient(90deg, #2B1728, #693754, #401C38)" }}
        >
          {pending ? "Saving…" : "Finish setup"}
        </button>
      </form>
    </div>
  );
}
