-- ============================================================
-- SMARTCEM - PHASE 4 : les champs geres par le serveur ne sont
-- jamais posables par un utilisateur authentifie.
-- Les fonctions sont SECURITY INVOKER : current_user reflète
-- le role JWT reel (authenticated / service_role / postgres).
-- ============================================================

-- 1) Un parent ne peut JAMAIS s auto-verifier
CREATE OR REPLACE FUNCTION public.sanitize_pcl()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  IF current_user = 'authenticated' THEN
    NEW.verified_at := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pcl_sanitize ON public.parent_child_links;
CREATE TRIGGER trg_pcl_sanitize
  BEFORE INSERT ON public.parent_child_links
  FOR EACH ROW EXECUTE FUNCTION public.sanitize_pcl();

-- 2) Note et statut d une reponse : reserves au serveur
CREATE OR REPLACE FUNCTION public.sanitize_answer()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  IF current_user = 'authenticated' THEN
    NEW.points_awarded := 0;
    NEW.status := 'unevaluable';
    NEW.deterministic_validated := false;
    NEW.ocr_confidence_score := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_answers_sanitize ON public.answers;
CREATE TRIGGER trg_answers_sanitize
  BEFORE INSERT ON public.answers
  FOR EACH ROW EXECUTE FUNCTION public.sanitize_answer();

-- 3) Score d une soumission : calcule par le serveur
CREATE OR REPLACE FUNCTION public.sanitize_submission()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  IF current_user = 'authenticated' THEN
    NEW.score_percentage := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_submissions_sanitize ON public.submissions;
CREATE TRIGGER trg_submissions_sanitize
  BEFORE INSERT OR UPDATE ON public.submissions
  FOR EACH ROW EXECUTE FUNCTION public.sanitize_submission();

-- 4) Reponses BEM : meme regle
CREATE OR REPLACE FUNCTION public.sanitize_bem_answer()
RETURNS trigger LANGUAGE plpgsql SET search_path = ''
AS $$
BEGIN
  IF current_user = 'authenticated' THEN
    NEW.points_awarded := 0;
    NEW.status := 'unevaluable';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bem_answers_sanitize ON public.bem_session_answers;
CREATE TRIGGER trg_bem_answers_sanitize
  BEFORE INSERT ON public.bem_session_answers
  FOR EACH ROW EXECUTE FUNCTION public.sanitize_bem_answer();

-- 5) Les mises a jour autorisees sont restreintes colonne par colonne
REVOKE UPDATE ON public.notifications FROM authenticated;
GRANT UPDATE (read_at) ON public.notifications TO authenticated;

REVOKE UPDATE ON public.remediation_assignments FROM authenticated;
GRANT UPDATE (status, completed_at) ON public.remediation_assignments TO authenticated;

REVOKE UPDATE ON public.submissions FROM authenticated;
GRANT UPDATE (completed_at, time_spent_seconds) ON public.submissions TO authenticated;
