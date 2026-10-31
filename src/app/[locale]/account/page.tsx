Set-Content -LiteralPath "src\app\[locale]\account\page.tsx" -Encoding UTF8 -Value @'
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { logout } from "@/actions/auth";
import { authCopy } from "@/lib/auth/copy";
import { isLocale } from "@/i18n/config";

export default async function AccountPage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) redirect("/fr/login");

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/${locale}/login`);

  const { data: profile } = await supabase
    .from("profiles")
    .select("role, first_name, last_name")
    .eq("id", user.id)
    .single();

  const { data: student } = await supabase
    .from("student_profiles")
    .select("grade_level, is_bem_candidate, total_xp")
    .eq("profile_id", user.id)
    .maybeSingle();

  const copy = authCopy[locale];

  return (
    <main className="mx-auto flex min-h-screen max-w-xl flex-col justify-center gap-6 px-5">
      <h1 className="text-4xl font-extrabold">{copy.account}</h1>
      <div className="flex flex-col gap-3 rounded-card border border-border bg-surface p-6 shadow-soft">
        <p><span className="font-bold">{copy.email} :</span> {user.email}</p>
        <p><span className="font-bold">{copy.firstName} :</span> {profile?.first_name}</p>
        <p><span className="font-bold">{copy.lastName} :</span> {profile?.last_name}</p>
        <p><span className="font-bold">{copy.role} :</span> {profile?.role}</p>
        {student && (
          <>
            <p><span className="font-bold">{copy.grade} :</span> {student.grade_level}</p>
            <p><span className="font-bold">XP :</span> {student.total_xp}</p>
          </>
        )}
      </div>
      <form action={logout}>
        <input type="hidden" name="locale" value={locale} />
        <button className="rounded-btn bg-primary px-5 py-3 font-bold text-primary-foreground">
          {copy.logout}
        </button>
      </form>
    </main>
  );
}
'@