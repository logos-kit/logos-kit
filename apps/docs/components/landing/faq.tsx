/**
 * Stacked questions, Ctrl's FAQ blocks (Refero: ctrl.xyz): uniform rounded
 * rows on the card surface, a plus that turns into a cross. Native
 * <details>, so it works without JavaScript and with the keyboard.
 */
export function Faq({ items }: { items: { q: string; a: React.ReactNode }[] }) {
  return (
    <div className="flex flex-col gap-3">
      {items.map((it) => (
        <details
          key={it.q}
          className="group rounded-3xl bg-fd-card px-6 py-5 open:pb-6 [&_summary::-webkit-details-marker]:hidden"
        >
          <summary className="flex cursor-pointer list-none items-center justify-between gap-6 font-semibold text-[17px] tracking-tight">
            {it.q}
            <span
              aria-hidden
              className="grid size-8 shrink-0 place-items-center rounded-full bg-fd-background text-lg transition-transform duration-200 group-open:rotate-45"
            >
              +
            </span>
          </summary>
          <div className="mt-3 max-w-2xl text-[15px] text-fd-muted-foreground leading-relaxed">
            {it.a}
          </div>
        </details>
      ))}
    </div>
  )
}
