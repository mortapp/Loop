export function PlaceholderScreen({ title, description }: { title: string; description: string }) {
  return (
    <div className="flex flex-col gap-2 rounded-2xl border border-dashed border-zinc-300 bg-white p-8 dark:border-zinc-700 dark:bg-zinc-950">
      <h1 className="text-xl font-semibold text-zinc-950 dark:text-zinc-50">{title}</h1>
      <p className="max-w-prose text-sm text-zinc-500 dark:text-zinc-400">{description}</p>
    </div>
  );
}
