import type { Metadata } from "next";
import type { ReactNode } from "react";
import { Geist, Geist_Mono, Fraunces } from "next/font/google";
import { getThemePreference } from "@/lib/theme";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

// Editorial heritage serif — wordmark, hero monetary figures, and
// section titles only. Never body copy. See docs/DESIGN_SYSTEM.md.
const fraunces = Fraunces({
  variable: "--font-fraunces",
  subsets: ["latin"],
  weight: ["500", "600"],
});

export const metadata: Metadata = {
  title: "LOOP",
  description:
    "LOOP — one unified value operating system. Earn, buy, own, return or resell, earn again.",
};

type RootLayoutProps = {
  children: ReactNode;
};

export default async function RootLayout({ children }: RootLayoutProps) {
  const theme = await getThemePreference();

  return (
    <html
      lang="en"
      data-theme={theme === "system" ? undefined : theme}
      className={`${geistSans.variable} ${geistMono.variable} ${fraunces.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">{children}</body>
    </html>
  );
}
