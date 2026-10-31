import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { logout } from "@/actions/auth";
import { authCopy } from "@/lib/auth/copy";
import { isLocale } from "@/i18n/config";

export default async function AccountPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) redirect("/fr/login");

  const supabase = await createClient();
  const { data } = await supabase.auth.getUser();
  if (!data.user) redirect(`/${locale}/login`);

  const profile = await supabase.from("profiles").select("id").eq("id", data.user.id).maybeSingle();
  const copy = authCopy[locale];

  return (
    <main className="mx-auto flex min-h-screen max-w-xl flex-col justify-center gap-6 px-5">
      <h1 className="text-4xl font-extrabold">{copy.account}</h1>
      <p className="rounded-card bg-surface p-5 shadow-soft">{data.user.email}</p>
      <p className="text-muted">{profile.data ? "Alerte : le profil ne devrait pas encore être lisible." : copy.locked}</p>
      <form action={logout}>
        <input type="hidden" name="locale" value={locale} />
        <button className="rounded-btn bg-primary px-5 py-3 font-bold text-primary-foreground">{copy.logout}</button>
      </form>
    </main>
  );
}
