import { notFound } from "next/navigation";
import { updatePassword } from "@/actions/auth";
import { AuthShell, buttonClass, inputClass, labelClass } from "@/components/auth/auth-shell";
import { authCopy } from "@/lib/auth/copy";
import { isLocale } from "@/i18n/config";

export default async function ResetPasswordPage({
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
  const message = error === "invalid" ? copy.invalid : error ? copy.failed : undefined;

  return (
    <AuthShell
      title={copy.reset}
      message={message}
      footer={[{ href: `/${locale}/login`, label: copy.login }]}
    >
      <form action={updatePassword} className="flex flex-col gap-4">
        <input type="hidden" name="locale" value={locale} />
        <label className={labelClass}>
          {copy.password}
          <input name="password" type="password" required minLength={8} maxLength={72} autoComplete="new-password" dir="ltr" className={inputClass} />
        </label>
        <button className={buttonClass}>{copy.save}</button>
      </form>
    </AuthShell>
  );
}