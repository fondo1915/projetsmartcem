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

  INSERT INTO public.profiles (id, role, first_name, last_name, locale)
  VALUES (
    NEW.id,
    requested_role::public.user_role,
    NEW.raw_user_meta_data ->> 'first_name',
    NEW.raw_user_meta_data ->> 'last_name',
    requested_locale
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

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
