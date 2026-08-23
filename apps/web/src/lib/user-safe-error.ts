type ErrorMetadata = {
  code?: unknown;
  status?: unknown;
};

function safeMetadata(error: unknown) {
  if (!error || typeof error !== "object") return undefined;

  const metadata = error as ErrorMetadata;
  return {
    code: typeof metadata.code === "string" ? metadata.code : undefined,
    status: typeof metadata.status === "number" ? metadata.status : undefined,
  };
}

export function userSafeServerError(
  operation: string,
  error: unknown,
  fallback = "We couldn't save that change. Please try again.",
) {
  console.error(`[${operation}] failed`, safeMetadata(error));
  return fallback;
}

export function userSafeAuthError(operation: "sign-in" | "sign-up", error: ErrorMetadata) {
  console.error(`[auth:${operation}] failed`, safeMetadata(error));

  switch (error.code) {
    case "invalid_credentials":
      return "Email or password is incorrect.";
    case "email_not_confirmed":
      return "Confirm your email before signing in.";
    case "user_already_exists":
    case "email_exists":
      return "An account already exists for this email.";
    case "weak_password":
      return "Use a stronger password with at least 8 characters.";
    case "signup_disabled":
      return "Account creation is temporarily unavailable.";
    case "over_request_rate_limit":
    case "over_email_send_rate_limit":
      return "Too many attempts. Wait a moment and try again.";
    default:
      return operation === "sign-in"
        ? "We couldn't sign you in. Please try again."
        : "We couldn't create your account. Please try again.";
  }
}
