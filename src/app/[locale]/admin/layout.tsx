import Link from "next/link";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { adminCopy } from "@/lib/admin/copy";
import { isLocale } from "@/i18n/config";

export default async function AdminLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) redirect("/fr/login");

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/${locale}/login`);

  const { data: me } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();
  if (me?.role !== "super_admin") redirect(`/${locale}`);

  const copy = adminCopy[locale];

  return (
    <div className="mx-auto flex min-h-screen max-w-5xl flex-col gap-6 px-5 py-8">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <h1 className="text-3xl font-extrabold">{copy.title}</h1>
        <nav className="flex flex-wrap gap-4 text-sm font-bold text-primary">
          <Link href={`/${locale}/admin`}>{copy.dashboard}</Link>
          <Link href={`/${locale}/admin/users`}>{copy.users}</Link>
          <Link href={`/${locale}/account`}>{copy.account}</Link>
        </nav>
      </header>
      {children}
    </div>
  );
}
