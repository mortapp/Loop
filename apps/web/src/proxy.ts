import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

// Next.js 16 renamed the middleware.ts convention to proxy.ts (same
// runtime behavior, new file/export name) — see
// node_modules/next/dist/docs/.../file-conventions/proxy.md.
//
// This runs on every request to keep the Supabase session cookie fresh
// (refreshing the access token before it expires) and to gate the
// authenticated app shell at (app)/**.

// These routes own their own authentication boundary. In particular, the AI
// routes accept a Supabase Bearer token from the native app, which the cookie-
// based proxy cannot authenticate. The handlers still validate the token and
// account membership before provider work or writes.
const PROXY_UNGUARDED_PATHS = [
  "/sign-in",
  "/sign-up",
  "/auth/callback",
  "/api/ai/chat",
  "/api/ai/confirm",
];

function isProxyUnguardedPath(pathname: string): boolean {
  return PROXY_UNGUARDED_PATHS.some((path) => pathname === path || pathname.startsWith(`${path}/`));
}

export async function proxy(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          for (const { name, value } of cookiesToSet) {
            request.cookies.set(name, value);
          }
          response = NextResponse.next({ request });
          for (const { name, value, options } of cookiesToSet) {
            response.cookies.set(name, value, options);
          }
        },
      },
    },
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { pathname } = request.nextUrl;

  if (!user && !isProxyUnguardedPath(pathname) && pathname !== "/") {
    const redirectUrl = new URL("/sign-in", request.url);
    redirectUrl.searchParams.set("next", pathname);
    return NextResponse.redirect(redirectUrl);
  }

  if (user && (pathname === "/sign-in" || pathname === "/sign-up")) {
    return NextResponse.redirect(new URL("/today", request.url));
  }

  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};
