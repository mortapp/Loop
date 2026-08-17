export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-full flex-1 flex-col items-center justify-center bg-zinc-50 px-4 py-16 dark:bg-black">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <span className="text-2xl font-semibold tracking-tight text-zinc-950 dark:text-zinc-50">
            LOOP
          </span>
          <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
            Earn. Buy. Own. Return or resell. Earn again.
          </p>
        </div>
        {children}
      </div>
    </div>
  );
}
