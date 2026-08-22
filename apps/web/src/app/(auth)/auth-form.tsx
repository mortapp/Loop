"use client";

import Link from "next/link";
import { useActionState } from "react";
import type { AuthActionState } from "./actions";
import { GoogleSignInButton } from "./google-sign-in-button";

export function AuthForm({
  mode,
  action,
}: {
  mode: "sign-in" | "sign-up";
  action: (prev: AuthActionState, formData: FormData) => Promise<AuthActionState>;
}) {
  const [state, formAction, pending] = useActionState<AuthActionState, FormData>(action, null);

  const isSignIn = mode === "sign-in";

  return (
    <form
      action={formAction}
      className="flex flex-col gap-4 rounded-[var(--radius-lg)] border border-[var(--color-border-subtle)] bg-[var(--color-surface)] p-6"
    >
      <h1 className="text-xs font-semibold tracking-[0.2em] text-[var(--color-text-secondary)]">
        {(isSignIn ? "Sign in" : "Create your account").toUpperCase()}
      </h1>

      <GoogleSignInButton />

      <div className="flex items-center gap-3 text-[var(--color-text-tertiary)]">
        <div className="h-px flex-1 bg-[var(--color-border-strong)] opacity-40" />
        <span className="text-xs">◇</span>
        <div className="h-px flex-1 bg-[var(--color-border-strong)] opacity-40" />
      </div>

      <label className="flex flex-col gap-1.5">
        <span className="text-[10px] font-semibold tracking-[0.15em] text-[var(--color-text-secondary)]">
          EMAIL
        </span>
        <input
          name="email"
          type="email"
          required
          autoComplete="email"
          placeholder="you@business.com"
          className="rounded-[var(--radius-sm)] border border-[var(--color-border-subtle)] bg-[var(--color-bg-secondary)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none placeholder:text-[var(--color-text-tertiary)] focus:border-[var(--color-brand)]"
        />
      </label>

      <label className="flex flex-col gap-1.5">
        <span className="text-[10px] font-semibold tracking-[0.15em] text-[var(--color-text-secondary)]">
          PASSWORD
        </span>
        <input
          name="password"
          type="password"
          required
          minLength={8}
          autoComplete={isSignIn ? "current-password" : "new-password"}
          placeholder="••••••••"
          className="rounded-[var(--radius-sm)] border border-[var(--color-border-subtle)] bg-[var(--color-bg-secondary)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none placeholder:text-[var(--color-text-tertiary)] focus:border-[var(--color-brand)]"
        />
      </label>

      {state?.error ? (
        <p className="text-sm text-[var(--color-danger-text)]" role="alert">
          {state.error}
        </p>
      ) : null}

      <button
        type="submit"
        disabled={pending}
        className="mt-2 rounded-[var(--radius-sm)] px-4 py-2.5 text-sm font-semibold tracking-wide text-[var(--color-on-accent)] transition-opacity disabled:opacity-50"
        style={{
          background: "linear-gradient(90deg, #2B1728, #693754, #401C38)",
        }}
      >
        {pending ? "Please wait…" : isSignIn ? "Sign in" : "Sign up"}
      </button>

      <p className="text-center text-sm text-[var(--color-text-tertiary)]">
        {isSignIn ? (
          <>
            Don&apos;t have an account?{" "}
            <Link href="/sign-up" className="font-semibold text-[var(--color-brand-text)]">
              Sign up
            </Link>
          </>
        ) : (
          <>
            Already have an account?{" "}
            <Link href="/sign-in" className="font-semibold text-[var(--color-brand-text)]">
              Sign in
            </Link>
          </>
        )}
      </p>
    </form>
  );
}
