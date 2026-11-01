import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { setUserRole } from "@/actions/admin";
import { adminCopy, adminRoles } from "@/lib/admin/copy";
import { isLocale } from "@/i18n/config";

const PAGE_SIZE = 20;

export default async function AdminUsersPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ q?: string; page?: string; ok?: string; error?: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) redirect("/fr/login");
  const { q, page, ok, error } = await searchParams;
  const copy = adminCopy[locale];

  const supabase = await createClient();
  const pageNum = Math.max(1, Number(page ?? 1) || 1);

  let query = supabase
    .from("profiles")
    .select("id, role, first_name, last_name, email, created_at, student_profiles(grade_level, total_xp)")
    .order("created_at", { ascending: false })
    .range((pageNum - 1) * PAGE_SIZE, pageNum * PAGE_SIZE - 1);
  if (q && q.trim()) {
    const term = q.trim().replace(/[%,()]/g, "");
    query = query.or(`first_name.ilike.%${term}%,last_name.ilike.%${term}%,email.ilike.%${term}%`);
  }
  const { data: users } = await query;

  const roleLabel = (role: string) =>
    adminRoles.includes(role as (typeof adminRoles)[number])
      ? copy[role as (typeof adminRoles)[number]]
      : role;

  return (
    <div className="flex flex-col gap-5">
      {ok && <p role="status" className="rounded-btn bg-success/15 px-4 py-3 text-sm font-bold text-success">{copy.ok}</p>}
      {error && <p role="alert" className="rounded-btn bg-fun/15 px-4 py-3 text-sm font-bold text-fun">
        {error === "forbidden" ? copy.forbidden : copy.invalid}
      </p>}

      <form method="get" className="flex gap-2">
        <input
          name="q"
          defaultValue={q ?? ""}
          placeholder={copy.search}
          className="w-full rounded-btn border border-border bg-surface px-4 py-3 outline-none focus:border-primary"
        />
        <button className="rounded-btn bg-primary px-5 py-3 font-bold text-primary-foreground">
          {copy.searchAction}
        </button>
      </form>

      <section className="overflow-x-auto rounded-card border border-border bg-surface shadow-soft">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-border text-start text-muted">
              <th className="p-3 text-start">{copy.name}</th>
              <th className="p-3 text-start">{copy.email}</th>
              <th className="p-3 text-start">{copy.grade}</th>
              <th className="p-3 text-start">{copy.created}</th>
              <th className="p-3 text-start">{copy.role}</th>
            </tr>
          </thead>
          <tbody>
            {(users ?? []).map((u) => (
              <tr key={u.id} className="border-b border-border">
                <td className="p-3 font-bold">{u.first_name} {u.last_name}</td>
                <td className="p-3" dir="ltr">{u.email}</td>
                <td className="p-3">{u.student_profiles?.[0]?.grade_level ?? "—"}</td>
                <td className="p-3 text-muted">{String(u.created_at).slice(0, 10)}</td>
                <td className="p-3">
                  <form action={setUserRole} className="flex items-center gap-2">
                    <input type="hidden" name="locale" value={locale} />
                    <input type="hidden" name="targetId" value={u.id} />
                    <select
                      name="newRole"
                      defaultValue={u.role}
                      className="rounded-btn border border-border bg-background px-2 py-1.5"
                    >
                      {adminRoles.map((r) => (
                        <option key={r} value={r}>{roleLabel(r)}</option>
                      ))}
                    </select>
                    <button className="rounded-btn bg-primary px-3 py-1.5 text-xs font-bold text-primary-foreground">
                      {copy.save}
                    </button>
                  </form>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <nav className="flex items-center justify-between text-sm font-bold text-primary">
        {pageNum > 1 ? (
          <a href={`/${locale}/admin/users?page=${pageNum - 1}${q ? `&q=${encodeURIComponent(q)}` : ""}`}>{copy.prev}</a>
        ) : <span />}
        <span className="text-muted">{copy.page} {pageNum}</span>
        {(users ?? []).length === PAGE_SIZE ? (
          <a href={`/${locale}/admin/users?page=${pageNum + 1}${q ? `&q=${encodeURIComponent(q)}` : ""}`}>{copy.next}</a>
        ) : <span />}
      </nav>
    </div>
  );
}
