import { notFound } from "next/navigation";
import { login } from "@/actions/auth";
import { AuthShell, buttonClass, inputClass, labelClass } from "@/components/auth/auth-shell";
import { authCopy } from "@/lib/auth/copy";
import { isLocale } from "@/i18n/config";

export default async function LoginPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const { error } = await searchParams;
  const copy = authCopy[locale];
  const message =
    error === "invalid" ? copy.invalid : error === "credentials" ? copy.credentials : undefined;

  return (
    <AuthShell
      title={copy.login}
      message={message}
      footer={[
        { href: `/${locale}/register`, label: copy.register },
        { href: `/${locale}/forgot-password`, label: copy.forgot },
      ]}
    >
      <form action={login} className="flex flex-col gap-4">
        <input type="hidden" name="locale" value={locale} />
        <label className={labelClass}>
          {copy.email}
          <input name="email" type="email" required autoComplete="email" dir="ltr" className={inputClass} />
        </label>
        <label className={labelClass}>
          {copy.password}
          <input name="password" type="password" required minLength={8} autoComplete="current-password" dir="ltr" className={inputClass} />
        </label>
        <button className={buttonClass}>{copy.login}</button>
      </form>
    </AuthShell>
  );
}