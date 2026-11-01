-- ============================================================
-- SMARTCEM - PHASE 5 : module Super Admin
-- ============================================================

-- 1) email sur profiles (backfill + unicite partielle)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;
UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE u.id = p.id AND p.email IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS profiles_email_uniq
  ON public.profiles (email) WHERE email IS NOT NULL;

-- 2) le trigger d inscription copie l email
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  requested_role text;
  requested_grade text;
  requested_locale text;
BEGIN
  requested_role := COALESCE(NEW.raw_user_meta_data ->> 'role', 'student');
  IF requested_role NOT IN ('student', 'parent') THEN
    RAISE EXCEPTION 'invalid_public_role';
  END IF;
  IF COALESCE(NEW.raw_user_meta_data ->> 'first_name', '') = ''
     OR COALESCE(NEW.raw_user_meta_data ->> 'last_name', '') = '' THEN
    RAISE EXCEPTION 'missing_name';
  END IF;
  requested_locale := COALESCE(NEW.raw_user_meta_data ->> 'locale', 'fr');
  IF requested_locale NOT IN ('fr', 'ar') THEN
    requested_locale := 'fr';
  END IF;
  INSERT INTO public.profiles (id, role, first_name, last_name, locale, email)
  VALUES (
    NEW.id,
    requested_role::public.user_role,
    NEW.raw_user_meta_data ->> 'first_name',
    NEW.raw_user_meta_data ->> 'last_name',
    requested_locale,
    NEW.email
  );
  IF requested_role = 'student' THEN
    requested_grade := COALESCE(NEW.raw_user_meta_data ->> 'grade_level', '');
    IF requested_grade NOT IN ('1AM', '2AM', '3AM', '4AM') THEN
      RAISE EXCEPTION 'invalid_grade';
    END IF;
    INSERT INTO public.student_profiles (profile_id, grade_level, academic_year)
    VALUES (NEW.id, requested_grade::public.grade_code, '2026-2027');
  END IF;
  RETURN NEW;
END;
$$;

-- 3) lectures reservees au super_admin
DROP POLICY IF EXISTS admin_read_profiles ON public.profiles;
CREATE POLICY admin_read_profiles ON public.profiles
  FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS admin_read_sp ON public.student_profiles;
CREATE POLICY admin_read_sp ON public.student_profiles
  FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS admin_read_pcl ON public.parent_child_links;
CREATE POLICY admin_read_pcl ON public.parent_child_links
  FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS admin_read_classes ON public.classes;
CREATE POLICY admin_read_classes ON public.classes
  FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS admin_read_subs ON public.subscriptions;
CREATE POLICY admin_read_subs ON public.subscriptions
  FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS admin_read_quotas ON public.ai_quotas;
CREATE POLICY admin_read_quotas ON public.ai_quotas
  FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS admin_read_audit ON public.audit_logs;
CREATE POLICY admin_read_audit ON public.audit_logs
  FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS admin_read_ai_audit ON public.ai_audit_logs;
CREATE POLICY admin_read_ai_audit ON public.ai_audit_logs
  FOR SELECT TO authenticated USING (public.is_admin());

-- 4) RPC : changement de role (journalise, protege contre l auto-demotion
--    et la perte du dernier super_admin)
CREATE OR REPLACE FUNCTION public.admin_set_user_role(
  target_id uuid, new_role public.user_role)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  caller public.user_role;
  previous_role public.user_role;
BEGIN
  caller := public.auth_role();
  IF caller IS DISTINCT FROM 'super_admin' THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF target_id = auth.uid() THEN
    RAISE EXCEPTION 'cannot_change_own_role';
  END IF;
  SELECT role INTO previous_role FROM public.profiles WHERE id = target_id;
  IF previous_role IS NULL THEN
    RAISE EXCEPTION 'target_not_found';
  END IF;
  IF previous_role = 'super_admin' AND new_role <> 'super_admin' THEN
    IF (SELECT COUNT(*) FROM public.profiles WHERE role = 'super_admin') <= 1 THEN
      RAISE EXCEPTION 'last_super_admin';
    END IF;
  END IF;
  UPDATE public.profiles
  SET role = new_role, updated_at = NOW()
  WHERE id = target_id;
  INSERT INTO public.audit_logs (actor_profile_id, action, entity_type, entity_id, metadata)
  VALUES (auth.uid(), 'admin_set_user_role', 'profiles', target_id,
          jsonb_build_object('from', previous_role, 'to', new_role));
END;
$$;
REVOKE ALL ON FUNCTION public.admin_set_user_role(uuid, public.user_role)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid, public.user_role)
  TO authenticated;

-- 5) RPC : statistiques (lecture seule, admin uniquement)
CREATE OR REPLACE FUNCTION public.admin_stats()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE result jsonb;
BEGIN
  IF public.auth_role() IS DISTINCT FROM 'super_admin' THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT jsonb_build_object(
    'total_users',  (SELECT COUNT(*) FROM public.profiles),
    'students',     (SELECT COUNT(*) FROM public.profiles WHERE role = 'student'),
    'parents',      (SELECT COUNT(*) FROM public.profiles WHERE role = 'parent'),
    'teachers',     (SELECT COUNT(*) FROM public.profiles WHERE role = 'teacher'),
    'admins',       (SELECT COUNT(*) FROM public.profiles WHERE role = 'super_admin'),
    'classes',      (SELECT COUNT(*) FROM public.classes),
    'submissions',  (SELECT COUNT(*) FROM public.submissions),
    'ai_calls',     (SELECT COUNT(*) FROM public.ai_audit_logs)
  ) INTO result;
  RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_stats() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_stats() TO authenticated;
