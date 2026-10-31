import { z } from "zod";

const localeSchema = z.enum(["fr", "ar"]);
const roleSchema = z.enum(["student", "parent"]);
const gradeSchema = z.enum(["1AM", "2AM", "3AM", "4AM"]);

export const loginSchema = z.object({
  email: z.string().trim().email().max(254),
  password: z.string().min(8).max(72),
  locale: localeSchema,
});

export const registerSchema = z.object({
  firstName: z.string().trim().min(2).max(100),
  lastName: z.string().trim().min(2).max(100),
  email: z.string().trim().email().max(254),
  password: z.string().min(8).max(72),
  role: roleSchema,
  gradeLevel: gradeSchema.optional(),
  locale: localeSchema,
}).superRefine((value, context) => {
  if (value.role === "student" && !value.gradeLevel) {
    context.addIssue({ code: z.ZodIssueCode.custom, path: ["gradeLevel"] });
  }
});

export const emailSchema = z.object({
  email: z.string().trim().email().max(254),
  locale: localeSchema,
});

export const passwordSchema = z.object({
  password: z.string().min(8).max(72),
  locale: localeSchema,
});
