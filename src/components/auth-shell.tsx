import Link from "next/link";
import type { ReactNode } from "react";

export const inputClass =
  "w-full rounded-btn border border-border bg-surface px-4 py-3 text-base outline-none focus:border-primary focus:ring-2 focus:ring-primary/30";
export const buttonClass =
  "w-full rounded-btn bg-primary px-6 py-3.5 text-base font-extrabold text-primary-foreground shadow-soft transition active:scale-95";
export const labelClass = "flex flex-col gap-1.5 font-bold";

export function AuthShell({
  title,
  message,
  success = false,
  footer,
  children,
}: {
  title: string;
  message?: string;
  success?: boolean;
  footer: { href: string; label: string }[];
  children: ReactNode;
}) {
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center gap-6 px-5 py-10">
      <Link href="/" className="text-2xl font-extrabold tracking-tight">
        SMART<span className="text-primary">CEM</span>
      </Link>
      <section className="flex flex-col gap-5 rounded-card border border-border bg-surface p-6 shadow-soft">
        <h1 className="text-3xl font-extrabold">{title}</h1>
        {message && (
          <p
            role={success ? "status" : "alert"}
            className={`rounded-btn px-4 py-3 text-sm font-bold ${
              success ? "bg-success/15 text-success" : "bg-fun/15 text-fun"
            }`}
          >
            {message}
          </p>
        )}
        {children}
      </section>
      <nav className="flex flex-wrap gap-4 text-sm font-bold text-primary">
        {footer.map((item) => (
          <Link key={item.href} href={item.href}>
            {item.label}
          </Link>
        ))}
      </nav>
    </main>
  );
}