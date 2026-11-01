"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { adminRoles } from "@/lib/admin/copy";

function localeOf(formData: FormData) {
  const value = String(formData.get("locale") ?? "fr");
  return value === "ar" ? "ar" : "fr";
}

export async function setUserRole(formData: FormData) {
  const locale = localeOf(formData);
  const targetId = String(formData.get("targetId") ?? "");
  const newRole = String(formData.get("newRole") ?? "");

  const isValidUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(targetId);
  if (!isValidUuid || !adminRoles.includes(newRole as (typeof adminRoles)[number])) {
    redirect(`/${locale}/admin/users?error=invalid`);
  }

  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/${locale}/login`);

  const { data: me } = await supabase.from("profiles").select("role").eq("id", user.id).single();
  if (me?.role !== "super_admin") redirect(`/${locale}?error=forbidden`);

  const { error } = await supabase.rpc("admin_set_user_role", {
    target_id: targetId,
    new_role: newRole,
  });
  if (error) redirect(`/${locale}/admin/users?error=forbidden`);

  revalidatePath(`/${locale}/admin/users`);
  redirect(`/${locale}/admin/users?ok=1`);
}
