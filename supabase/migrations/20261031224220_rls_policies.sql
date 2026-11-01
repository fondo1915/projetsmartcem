-- ============================================================
-- SMARTCEM - PHASE 4 : politiques RLS par role
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

-- ============ profiles ============
DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
DROP POLICY IF EXISTS profiles_select_children ON public.profiles;
DROP POLICY IF EXISTS profiles_select_class ON public.profiles;
DROP POLICY IF EXISTS profiles_update_own ON public.profiles;

CREATE POLICY profiles_select_own ON public.profiles
  FOR SELECT TO authenticated USING (id = auth.uid());

CREATE POLICY profiles_select_children ON public.profiles
  FOR SELECT TO authenticated USING (public.is_parent_of(id));

CREATE POLICY profiles_select_class ON public.profiles
  FOR SELECT TO authenticated USING (public.is_teacher_of(id));

CREATE POLICY profiles_update_own ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid()) WITH CHECK (id = auth.uid());

-- Le role ne doit JAMAIS etre modifiable par l'utilisateur (anti-escalade)
REVOKE UPDATE ON public.profiles FROM authenticated;
GRANT UPDATE (first_name, last_name, avatar_url, locale) ON public.profiles TO authenticated;

-- ============ student_profiles ============
DROP POLICY IF EXISTS sp_select_own ON public.student_profiles;
DROP POLICY IF EXISTS sp_select_children ON public.student_profiles;
DROP POLICY IF EXISTS sp_select_class ON public.student_profiles;

CREATE POLICY sp_select_own ON public.student_profiles
  FOR SELECT TO authenticated USING (profile_id = auth.uid());

CREATE POLICY sp_select_children ON public.student_profiles
  FOR SELECT TO authenticated USING (public.is_parent_of(profile_id));

CREATE POLICY sp_select_class ON public.student_profiles
  FOR SELECT TO authenticated USING (public.is_teacher_of(profile_id));

-- XP, serie, niveau : reserves au serveur (anti-triche)
REVOKE UPDATE ON public.student_profiles FROM authenticated;

-- ============ parent_child_links ============
DROP POLICY IF EXISTS pcl_select_own ON public.parent_child_links;
DROP POLICY IF EXISTS pcl_insert_request ON public.parent_child_links;
DROP POLICY IF EXISTS pcl_delete_own ON public.parent_child_links;

CREATE POLICY pcl_select_own ON public.parent_child_links
  FOR SELECT TO authenticated
  USING (parent_id = auth.uid() OR student_id = auth.uid());

CREATE POLICY pcl_insert_request ON public.parent_child_links
  FOR INSERT TO authenticated
  WITH CHECK (parent_id = auth.uid() AND public.is_parent());

CREATE POLICY pcl_delete_own ON public.parent_child_links
  FOR DELETE TO authenticated
  USING (parent_id = auth.uid());

-- ============ classes / enrollments (fonctions anti-recursion) ============
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

DROP POLICY IF EXISTS ce_select ON public.class_enrollments;
DROP POLICY IF EXISTS ce_crud ON public.class_enrollments;

CREATE POLICY ce_select ON public.class_enrollments
  FOR SELECT TO authenticated
  USING (student_id = auth.uid() OR public.teaches_class(class_id));

CREATE POLICY ce_crud ON public.class_enrollments
  FOR ALL TO authenticated
  USING (public.teaches_class(class_id))
  WITH CHECK (public.teaches_class(class_id));

-- ============ teacher_profiles ============
DROP POLICY IF EXISTS tp_select_own ON public.teacher_profiles;

CREATE POLICY tp_select_own ON public.teacher_profiles
  FOR SELECT TO authenticated USING (profile_id = auth.uid());

-- ============ Referentiel : lecture pour les connectes ============
DO $block$
DECLARE t text;
BEGIN
  FOR t IN
    SELECT unnest(ARRAY[
      'subjects','domains','chapters','competencies','apc_indicators',
      'courses','lessons','exercises','questions','rubrics','step_solutions',
      'rag_documents','rag_chunks','bem_subjects','subscription_plans'
    ])
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I_select_all ON public.%I', t, t);
    EXECUTE format(
      'CREATE POLICY %I_select_all ON public.%I FOR SELECT TO authenticated USING (true)',
      t, t);
  END LOOP;
END
$block$;

-- ============ Submissions / answers / errors / BKT ============
DROP POLICY IF EXISTS submissions_select ON public.submissions;
DROP POLICY IF EXISTS submissions_insert ON public.submissions;
DROP POLICY IF EXISTS submissions_update ON public.submissions;

CREATE POLICY submissions_select ON public.submissions
  FOR SELECT TO authenticated USING (public.has_student_access(student_id));

CREATE POLICY submissions_insert ON public.submissions
  FOR INSERT TO authenticated WITH CHECK (student_id = auth.uid());

CREATE POLICY submissions_update ON public.submissions
  FOR UPDATE TO authenticated
  USING (student_id = auth.uid()) WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS answers_select ON public.answers;
DROP POLICY IF EXISTS answers_insert ON public.answers;

CREATE POLICY answers_select ON public.answers
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.submissions s
    WHERE s.id = submission_id AND public.has_student_access(s.student_id)
  ));

CREATE POLICY answers_insert ON public.answers
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.submissions s
    WHERE s.id = submission_id AND s.student_id = auth.uid()
  ));

DROP POLICY IF EXISTS error_logs_select ON public.error_logs;
DROP POLICY IF EXISTS error_logs_insert ON public.error_logs;

CREATE POLICY error_logs_select ON public.error_logs
  FOR SELECT TO authenticated USING (public.has_student_access(student_id));

CREATE POLICY error_logs_insert ON public.error_logs
  FOR INSERT TO authenticated WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS sks_select ON public.student_knowledge_states;

CREATE POLICY sks_select ON public.student_knowledge_states
  FOR SELECT TO authenticated USING (public.has_student_access(student_id));

-- ============ OCR / corrections IA ============
DROP POLICY IF EXISTS ocr_select ON public.ocr_transcriptions;
DROP POLICY IF EXISTS ocr_insert ON public.ocr_transcriptions;

CREATE POLICY ocr_select ON public.ocr_transcriptions
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.answers a
    JOIN public.submissions s ON s.id = a.submission_id
    WHERE a.id = answer_id AND public.has_student_access(s.student_id)
  ));

CREATE POLICY ocr_insert ON public.ocr_transcriptions
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.answers a
    JOIN public.submissions s ON s.id = a.submission_id
    WHERE a.id = answer_id AND s.student_id = auth.uid()
  ));

DROP POLICY IF EXISTS ai_corr_select ON public.ai_corrections;

CREATE POLICY ai_corr_select ON public.ai_corrections
  FOR SELECT TO authenticated USING (public.has_student_access(student_id));

-- ============ Remediation / repetition espacee ============
DROP POLICY IF EXISTS remed_select ON public.remediation_assignments;
DROP POLICY IF EXISTS remed_update ON public.remediation_assignments;

CREATE POLICY remed_select ON public.remediation_assignments
  FOR SELECT TO authenticated USING (public.has_student_access(student_id));

CREATE POLICY remed_update ON public.remediation_assignments
  FOR UPDATE TO authenticated
  USING (student_id = auth.uid()) WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS sr_select ON public.spaced_repetition_reviews;

CREATE POLICY sr_select ON public.spaced_repetition_reviews
  FOR SELECT TO authenticated
  USING (student_id = auth.uid() OR public.is_parent_of(student_id));

-- ============ BEM ============
DROP POLICY IF EXISTS bem_sessions_select ON public.bem_sessions;
DROP POLICY IF EXISTS bem_sessions_insert ON public.bem_sessions;
DROP POLICY IF EXISTS bem_sessions_update ON public.bem_sessions;

CREATE POLICY bem_sessions_select ON public.bem_sessions
  FOR SELECT TO authenticated USING (public.has_student_access(student_id));

CREATE POLICY bem_sessions_insert ON public.bem_sessions
  FOR INSERT TO authenticated WITH CHECK (student_id = auth.uid());

CREATE POLICY bem_sessions_update ON public.bem_sessions
  FOR UPDATE TO authenticated
  USING (student_id = auth.uid()) WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS bem_answers_select ON public.bem_session_answers;
DROP POLICY IF EXISTS bem_answers_insert ON public.bem_session_answers;

CREATE POLICY bem_answers_select ON public.bem_session_answers
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.bem_sessions bs
    WHERE bs.id = bem_session_id AND public.has_student_access(bs.student_id)
  ));

CREATE POLICY bem_answers_insert ON public.bem_session_answers
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.bem_sessions bs
    WHERE bs.id = bem_session_id AND bs.student_id = auth.uid()
  ));

DROP POLICY IF EXISTS bem_readiness_select ON public.bem_readiness_estimates;

CREATE POLICY bem_readiness_select ON public.bem_readiness_estimates
  FOR SELECT TO authenticated USING (public.has_student_access(student_id));

-- ============ Notifications / abonnements / quotas ============
DROP POLICY IF EXISTS notif_select ON public.notifications;
DROP POLICY IF EXISTS notif_update ON public.notifications;

CREATE POLICY notif_select ON public.notifications
  FOR SELECT TO authenticated USING (recipient_profile_id = auth.uid());

CREATE POLICY notif_update ON public.notifications
  FOR UPDATE TO authenticated
  USING (recipient_profile_id = auth.uid())
  WITH CHECK (recipient_profile_id = auth.uid());

DROP POLICY IF EXISTS subs_select ON public.subscriptions;

CREATE POLICY subs_select ON public.subscriptions
  FOR SELECT TO authenticated USING (profile_id = auth.uid());

DROP POLICY IF EXISTS quotas_select ON public.ai_quotas;

CREATE POLICY quotas_select ON public.ai_quotas
  FOR SELECT TO authenticated USING (profile_id = auth.uid());

-- ai_audit_logs, audit_logs, content_versions : deny-all (service_role seul)
