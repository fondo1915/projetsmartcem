import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { adminCopy } from "@/lib/admin/copy";
import { isLocale } from "@/i18n/config";

export default async function AdminDashboard({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) redirect("/fr/login");
  const copy = adminCopy[locale];

  const supabase = await createClient();
  const { data: stats } = await supabase.rpc("admin_stats");
  const { data: logs } = await supabase
    .from("audit_logs")
    .select("action, entity_type, created_at, metadata")
    .order("created_at", { ascending: false })
    .limit(10);

  const cards = [
    { label: copy.totalUsers, value: stats?.total_users ?? 0 },
    { label: copy.students, value: stats?.students ?? 0 },
    { label: copy.parents, value: stats?.parents ?? 0 },
    { label: copy.teachers, value: stats?.teachers ?? 0 },
    { label: copy.admins, value: stats?.admins ?? 0 },
    { label: copy.classes, value: stats?.classes ?? 0 },
    { label: copy.submissions, value: stats?.submissions ?? 0 },
    { label: copy.aiCalls, value: stats?.ai_calls ?? 0 },
  ];

  return (
    <div className="flex flex-col gap-6">
      <section className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        {cards.map((c) => (
          <div key={c.label} className="flex flex-col gap-1 rounded-card border border-border bg-surface p-4 shadow-soft">
            <span className="text-2xl font-extrabold text-primary">{c.value}</span>
            <span className="text-xs font-bold text-muted">{c.label}</span>
          </div>
        ))}
      </section>

      <section className="flex flex-col gap-3 rounded-card border border-border bg-surface p-5 shadow-soft">
        <h2 className="text-lg font-extrabold">{copy.recentActivity}</h2>
        {!logs || logs.length === 0 ? (
          <p className="text-sm text-muted">{copy.noActivity}</p>
        ) : (
          <ul className="flex flex-col gap-2 text-sm">
            {logs.map((log, i) => (
              <li key={i} className="flex flex-wrap justify-between gap-2 border-b border-border pb-2">
                <span className="font-bold">{log.action}</span>
                <span className="text-muted">
                  {log.entity_type} · {String(log.created_at).slice(0, 16).replace("T", " ")}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
