"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { emailSchema, loginSchema, passwordSchema, registerSchema } from "@/lib/auth/validation";

function localeOf(formData: FormData) {
  const value = String(formData.get("locale") ?? "fr");
  return value === "ar" ? "ar" : "fr";
}

export async function login(formData: FormData) {
  const locale = localeOf(formData);
  const parsed = loginSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
    locale,
  });

  if (!parsed.success) redirect(`/${locale}/login?error=invalid`);

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: parsed.data.email,
    password: parsed.data.password,
  });
  if (error) redirect(`/${locale}/login?error=credentials`);

  redirect(`/${locale}/account`);
}

export async function register(formData: FormData) {
  const locale = localeOf(formData);
  const parsed = registerSchema.safeParse({
    firstName: formData.get("firstName"),
    lastName: formData.get("lastName"),
    email: formData.get("email"),
    password: formData.get("password"),
    role: formData.get("role"),
    gradeLevel: formData.get("gradeLevel") || undefined,
    locale,
  });

  if (!parsed.success) redirect(`/${locale}/register?error=invalid`);

  const supabase = await createClient();
  const { error } = await supabase.auth.signUp({
    email: parsed.data.email,
    password: parsed.data.password,
    options: {
      data: {
        first_name: parsed.data.firstName,
        last_name: parsed.data.lastName,
        role: parsed.data.role,
        grade_level: parsed.data.gradeLevel ?? null,
        locale,
      },
    },
  });

  if (error) redirect(`/${locale}/register?error=failed`);
  redirect(`/${locale}/account`);
}

export async function requestPasswordReset(formData: FormData) {
  const locale = localeOf(formData);
  const parsed = emailSchema.safeParse({ email: formData.get("email"), locale });
  if (!parsed.success) redirect(`/${locale}/forgot-password?error=invalid`);

  const supabase = await createClient();
  const origin = process.env.NEXT_PUBLIC_SITE_URL ?? "http://127.0.0.1:3000";

  await supabase.auth.resetPasswordForEmail(parsed.data.email, {
    redirectTo: `${origin}/auth/callback?next=/${locale}/reset-password`,
  });

  redirect(`/${locale}/forgot-password?sent=1`);
}

export async function updatePassword(formData: FormData) {
  const locale = localeOf(formData);
  const parsed = passwordSchema.safeParse({ password: formData.get("password"), locale });
  if (!parsed.success) redirect(`/${locale}/reset-password?error=invalid`);

  const supabase = await createClient();
  const { error } = await supabase.auth.updateUser({ password: parsed.data.password });
  if (error) redirect(`/${locale}/reset-password?error=failed`);

  redirect(`/${locale}/account`);
}

export async function logout(formData: FormData) {
  const locale = localeOf(formData);
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect(`/${locale}/login`);
}