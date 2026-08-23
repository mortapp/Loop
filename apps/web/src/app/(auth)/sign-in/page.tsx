import { AuthForm } from "../auth-form";
import { signIn } from "../actions";

const ERROR_MESSAGES: Record<string, string> = {
  auth_callback_failed: "That sign-in link didn't work — it may have expired. Try signing in again.",
};

const NOTICE_MESSAGES: Record<string, string> = {
  check_email: "Check your email to confirm your account, then sign in.",
};

export default async function SignInPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; notice?: string }>;
}) {
  const { error, notice } = await searchParams;

  const initialMessage = error
    ? { kind: "error" as const, text: ERROR_MESSAGES[error] ?? "Something went wrong. Try again." }
    : notice
      ? { kind: "notice" as const, text: NOTICE_MESSAGES[notice] ?? notice }
      : null;

  return <AuthForm mode="sign-in" action={signIn} initialMessage={initialMessage} />;
}
