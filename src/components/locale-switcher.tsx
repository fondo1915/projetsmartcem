"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { locales, type Locale } from "@/i18n/config";

const labels: Record<Locale, string> = { fr: "FR", ar: "عربي" };

export function LocaleSwitcher({ current }: { current: Locale }) {
  const pathname = usePathname();
  const rest = pathname.replace(/^\/(fr|ar)(?=\/|$)/, "") || "";

  return (
    <nav aria-label="language" className="flex gap-1 rounded-full border border-border bg-surface p-1 shadow-soft">
      {locales.map((l) => (
        <Link
          key={l}
          href={`/${l}${rest}`}
          hrefLang={l}
          className={`rounded-full px-3 py-1.5 text-sm font-bold transition-colors ${
            l === current ? "bg-primary text-primary-foreground" : "text-muted hover:text-foreground"
          }`}
        >
          {labels[l]}
        </Link>
      ))}
    </nav>
  );
}