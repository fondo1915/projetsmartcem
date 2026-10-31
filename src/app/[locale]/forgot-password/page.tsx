import { notFound } from "next/navigation";
import { requestPasswordReset } from "@/actions/auth";
import { AuthShell, buttonClass, inputClass, labelClass } from "@/components/auth/auth-shell";
import { authCopy } from "@/lib/auth/copy";
import { isLocale } from "@/i18n/config";

export default async function ForgotPasswordPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ error?: string; sent?: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const { error, sent } = await searchParams;
  const copy = authCopy[locale];
  const message = sent ? copy.sent : error ? copy.invalid : undefined;

  return (
    <AuthShell
      title={copy.forgot}
      message={message}
      success={Boolean(sent)}
      footer={[{ href: `/${locale}/login`, label: copy.login }]}
    >
      <form action={requestPasswordReset} className="flex flex-col gap-4">
        <input type="hidden" name="locale" value={locale} />
        <label className={labelClass}>
          {copy.email}
          <input name="email" type="email" required autoComplete="email" dir="ltr" className={inputClass} />
        </label>
        <button className={buttonClass}>{copy.send}</button>
      </form>
    </AuthShell>
  );
}