import { notFound } from "next/navigation";
import { register } from "@/actions/auth";
import { AuthShell, buttonClass, inputClass, labelClass } from "@/components/auth/auth-shell";
import { authCopy } from "@/lib/auth/copy";
import { isLocale } from "@/i18n/config";

export default async function RegisterPage({
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
    error === "invalid" ? copy.invalid : error === "failed" ? copy.taken : undefined;

  return (
    <AuthShell
      title={copy.register}
      message={message}
      footer={[{ href: `/${locale}/login`, label: copy.login }]}
    >
      <form action={register} className="flex flex-col gap-4">
        <input type="hidden" name="locale" value={locale} />
        <label className={labelClass}>
          {copy.firstName}
          <input name="firstName" required minLength={2} maxLength={100} autoComplete="given-name" className={inputClass} />
        </label>
        <label className={labelClass}>
          {copy.lastName}
          <input name="lastName" required minLength={2} maxLength={100} autoComplete="family-name" className={inputClass} />
        </label>
        <label className={labelClass}>
          {copy.email}
          <input name="email" type="email" required autoComplete="email" dir="ltr" className={inputClass} />
        </label>
        <label className={labelClass}>
          {copy.password}
          <input name="password" type="password" required minLength={8} maxLength={72} autoComplete="new-password" dir="ltr" className={inputClass} />
        </label>
        <fieldset className="flex flex-col gap-2">
          <legend className="font-bold">{copy.role}</legend>
          <label className="flex items-center gap-2">
            <input type="radio" name="role" value="student" defaultChecked /> {copy.student}
          </label>
          <label className="flex items-center gap-2">
            <input type="radio" name="role" value="parent" /> {copy.parent}
          </label>
        </fieldset>
        <label className={labelClass}>
          {copy.gradeHint}
          <select name="gradeLevel" defaultValue="" className={inputClass}>
            <option value="">—</option>
            <option value="1AM">1AM</option>
            <option value="2AM">2AM</option>
            <option value="3AM">3AM</option>
            <option value="4AM">4AM</option>
          </select>
        </label>
        <button className={buttonClass}>{copy.register}</button>
      </form>
    </AuthShell>
  );
}