-- ============================================================
-- SMARTCEM - PHASE 4 : correction apres migration v2 defectueuse
-- 1. Re-cree les fonctions auxiliaires
-- 2. Remplace les politiques recursives classes/class_enrollments
-- 3. Retire le GRANT de triche sur student_profiles
-- ============================================================

CREATE OR REPLACE FUNCTION public.auth_role()
RETURNS public.user_role
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = ''
AS $$ SELECT p.role FROM public.profiles p WHERE p.id = auth.uid(); $$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = ''
AS $$ SELECT public.auth_role() = 'super_admin'::public.user_role; $$;

CREATE OR REPLACE FUNCTION public.is_teacher()
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = ''
AS $$ SELECT public.auth_role() = 'teacher'::public.user_role; $$;

CREATE OR REPLACE FUNCTION public.is_student()
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = ''
AS $$ SELECT public.auth_role() = 'student'::public.user_role; $$;

CREATE OR REPLACE FUNCTION public.is_parent()
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = ''
AS $$ SELECT public.auth_role() = 'parent'::public.user_role; $$;

CREATE OR REPLACE FUNCTION public.is_parent_of(target_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.parent_child_links pcl
    WHERE pcl.parent_id = auth.uid() AND pcl.student_id = target_id
      AND pcl.verified_at IS NOT NULL
  );
$$;

CREATE OR REPLACE FUNCTION public.is_teacher_of(target_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.class_enrollments ce
    JOIN public.classes c ON c.id = ce.class_id
    WHERE c.teacher_id = auth.uid() AND ce.student_id = target_id
  );
$$;

CREATE OR REPLACE FUNCTION public.teaches_class(target_class uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.classes c
    WHERE c.id = target_class AND c.teacher_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.is_enrolled_in(target_class uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.class_enrollments ce
    WHERE ce.class_id = target_class AND ce.student_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.has_student_access(target_id uuid)
RETURNS boolean LANGUAGE sql SECURITY DEFINER STABLE SET search_path = ''
AS $$
  SELECT target_id = auth.uid()
      OR public.is_parent_of(target_id)
      OR public.is_teacher_of(target_id);
$$;

-- ============ classes : politiques anti-recursion ============
DROP POLICY IF EXISTS classes_select_own ON public.classes;
DROP POLICY IF EXISTS classes_select_enrolled ON public.classes;
DROP POLICY IF EXISTS classes_crud_own ON public.classes;

CREATE POLICY classes_select_own ON public.classes
  FOR SELECT TO authenticated USING (teacher_id = auth.uid());

CREATE POLICY classes_select_enrolled ON public.classes
  FOR SELECT TO authenticated USING (public.is_enrolled_in(id));

CREATE POLICY classes_crud_own ON public.classes
  FOR ALL TO authenticated
  USING (teacher_id = auth.uid()) WITH CHECK (teacher_id = auth.uid());

-- ============ class_enrollments : politiques anti-recursion ============
DROP POLICY IF EXISTS ce_select ON public.class_enrollments;
DROP POLICY IF EXISTS ce_crud ON public.class_enrollments;

CREATE POLICY ce_select ON public.class_enrollments
  FOR SELECT TO authenticated
  USING (student_id = auth.uid() OR public.teaches_class(class_id));

CREATE POLICY ce_crud ON public.class_enrollments
  FOR ALL TO authenticated
  USING (public.teaches_class(class_id))
  WITH CHECK (public.teaches_class(class_id));

-- ============ anti-triche : ni le niveau ni les XP ne sont modifiables ============
REVOKE UPDATE ON public.student_profiles FROM authenticated;
