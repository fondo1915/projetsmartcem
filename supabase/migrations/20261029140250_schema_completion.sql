-- =============================================================================
-- SMARTCEM - Proposition B : complétion du schéma
-- RELECTURE SEULEMENT - ne pas exécuter sans validation explicite
-- Ajoute les domaines manquants du cahier des charges, sans casser l'existant.
-- Toutes les nouvelles tables sont verrouillées en RLS deny-all.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "vector";

-- ---------------------------------------------------------------------------
-- Extension taxonomie des erreurs, section 10 du cahier des charges
-- Existant : sign_error, arithmetic_calc, algorithmic_step,
-- math_property_violation, reading_comprehension, notation_formalism, slip_inattention
-- ---------------------------------------------------------------------------
ALTER TYPE public.error_category ADD VALUE IF NOT EXISTS 'method_error';
ALTER TYPE public.error_category ADD VALUE IF NOT EXISTS 'reasoning_error';
ALTER TYPE public.error_category ADD VALUE IF NOT EXISTS 'comprehension_error';
ALTER TYPE public.error_category ADD VALUE IF NOT EXISTS 'transformation_error';
ALTER TYPE public.error_category ADD VALUE IF NOT EXISTS 'representation_error';
ALTER TYPE public.error_category ADD VALUE IF NOT EXISTS 'other_error';

-- ---------------------------------------------------------------------------
-- Profils enseignants
-- ---------------------------------------------------------------------------
CREATE TABLE public.teacher_profiles (
  profile_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  bio TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Cours et leçons, liés aux chapitres officiels
-- ---------------------------------------------------------------------------
CREATE TABLE public.courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chapter_id UUID NOT NULL REFERENCES public.chapters(id) ON DELETE RESTRICT,
  title_fr VARCHAR(255) NOT NULL,
  title_ar VARCHAR(255) NOT NULL,
  summary_fr TEXT,
  summary_ar TEXT,
  order_index INTEGER NOT NULL DEFAULT 1,
  status content_status NOT NULL DEFAULT 'draft',
  version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  title_fr VARCHAR(255) NOT NULL,
  title_ar VARCHAR(255) NOT NULL,
  content_fr TEXT,
  content_ar TEXT,
  latex_content TEXT,
  order_index INTEGER NOT NULL DEFAULT 1,
  status content_status NOT NULL DEFAULT 'draft',
  version INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- OCR : image, transcription, confiance, validation élève
-- ---------------------------------------------------------------------------
CREATE TABLE public.ocr_transcriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  answer_id UUID NOT NULL REFERENCES public.answers(id) ON DELETE CASCADE,
  original_image_path TEXT NOT NULL,
  ocr_raw_text TEXT,
  transcribed_latex TEXT,
  confidence_score NUMERIC(3,2) CHECK (confidence_score IS NULL OR (confidence_score BETWEEN 0 AND 1)),
  validated_by_student BOOLEAN NOT NULL DEFAULT FALSE,
  validated_text TEXT,
  provider_name VARCHAR(50),
  model_name VARCHAR(100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Corrections IA structurées
-- ---------------------------------------------------------------------------
CREATE TABLE public.ai_corrections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  answer_id UUID NOT NULL UNIQUE REFERENCES public.answers(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  competency_id UUID REFERENCES public.competencies(id) ON DELETE SET NULL,
  provider_name VARCHAR(50) NOT NULL,
  model_name VARCHAR(100) NOT NULL,
  prompt_version VARCHAR(50),
  overall_status answer_status NOT NULL DEFAULT 'unevaluable',
  steps_analysis JSONB NOT NULL DEFAULT '[]'::jsonb,
  errors_detected JSONB NOT NULL DEFAULT '[]'::jsonb,
  diagnostic JSONB,
  confidence_score NUMERIC(4,3) CHECK (confidence_score IS NULL OR (confidence_score BETWEEN 0 AND 1)),
  prompt_tokens INTEGER NOT NULL DEFAULT 0,
  completion_tokens INTEGER NOT NULL DEFAULT 0,
  cost_usd NUMERIC(8,6) NOT NULL DEFAULT 0,
  latency_ms INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Remédiation personnalisée
-- ---------------------------------------------------------------------------
CREATE TYPE remediation_type AS ENUM ('lesson_review','guided_example','easy_exercise','targeted_exercise','spaced_review','bem_training');
CREATE TYPE remediation_status AS ENUM ('assigned','in_progress','completed','skipped','expired');

CREATE TABLE public.remediation_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  competency_id UUID NOT NULL REFERENCES public.competencies(id) ON DELETE RESTRICT,
  source_answer_id UUID REFERENCES public.answers(id) ON DELETE SET NULL,
  remediation_type remediation_type NOT NULL,
  exercise_id UUID REFERENCES public.exercises(id) ON DELETE SET NULL,
  lesson_id UUID REFERENCES public.lessons(id) ON DELETE SET NULL,
  status remediation_status NOT NULL DEFAULT 'assigned',
  due_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Répétition espacée : historique des révisions
-- ---------------------------------------------------------------------------
CREATE TABLE public.spaced_repetition_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_knowledge_state_id UUID NOT NULL REFERENCES public.student_knowledge_states(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  competency_id UUID NOT NULL REFERENCES public.competencies(id) ON DELETE RESTRICT,
  scheduled_for TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ,
  was_successful BOOLEAN,
  new_mastery_probability NUMERIC(4,3),
  new_stability_factor NUMERIC(6,2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- RAG pédagogique
-- ---------------------------------------------------------------------------
CREATE TABLE public.rag_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grade_level grade_code,
  subject_id UUID REFERENCES public.subjects(id) ON DELETE SET NULL,
  chapter_id UUID REFERENCES public.chapters(id) ON DELETE SET NULL,
  title_fr VARCHAR(255) NOT NULL,
  title_ar VARCHAR(255),
  source_type VARCHAR(50) NOT NULL DEFAULT 'official_manual',
  source_ref TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  status content_status NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.rag_chunks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES public.rag_documents(id) ON DELETE CASCADE,
  chunk_index INTEGER NOT NULL,
  content TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  embedding_model VARCHAR(100),
  embedding vector(1536),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_document_chunk UNIQUE (document_id, chunk_index)
);

-- ---------------------------------------------------------------------------
-- BEM 4AM
-- ---------------------------------------------------------------------------
CREATE TABLE public.bem_subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE RESTRICT,
  year INTEGER NOT NULL CHECK (year BETWEEN 2000 AND 2100),
  title_fr VARCHAR(255) NOT NULL,
  title_ar VARCHAR(255),
  official_ref VARCHAR(100),
  duration_minutes INTEGER NOT NULL DEFAULT 120,
  total_points NUMERIC(5,2) NOT NULL DEFAULT 20.00,
  pdf_url TEXT,
  status content_status NOT NULL DEFAULT 'draft',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TYPE bem_session_status AS ENUM ('in_progress','completed','abandoned','graded');

CREATE TABLE public.bem_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  bem_subject_id UUID NOT NULL REFERENCES public.bem_subjects(id) ON DELETE RESTRICT,
  status bem_session_status NOT NULL DEFAULT 'in_progress',
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  time_spent_seconds INTEGER NOT NULL DEFAULT 0,
  score NUMERIC(5,2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.bem_session_answers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bem_session_id UUID NOT NULL REFERENCES public.bem_sessions(id) ON DELETE CASCADE,
  question_id UUID REFERENCES public.questions(id) ON DELETE SET NULL,
  question_label VARCHAR(50),
  student_raw_input TEXT,
  transcribed_latex TEXT,
  status answer_status NOT NULL DEFAULT 'unevaluable',
  points_awarded NUMERIC(4,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.bem_readiness_estimates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  subject_id UUID NOT NULL REFERENCES public.subjects(id) ON DELETE RESTRICT,
  readiness_score NUMERIC(4,3) NOT NULL CHECK (readiness_score BETWEEN 0 AND 1),
  confidence_score NUMERIC(4,3) NOT NULL DEFAULT 0.500 CHECK (confidence_score BETWEEN 0 AND 1),
  details JSONB NOT NULL DEFAULT '{}'::jsonb,
  computed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------
CREATE TABLE public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL,
  title_fr VARCHAR(255) NOT NULL,
  title_ar VARCHAR(255),
  body_fr TEXT,
  body_ar TEXT,
  related_entity_type VARCHAR(50),
  related_entity_id UUID,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- Abonnements et quotas
-- ---------------------------------------------------------------------------
CREATE TABLE public.subscription_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) NOT NULL UNIQUE,
  name_fr VARCHAR(100) NOT NULL,
  name_ar VARCHAR(100),
  monthly_price_dzd INTEGER NOT NULL DEFAULT 0,
  yearly_price_dzd INTEGER NOT NULL DEFAULT 0,
  ai_daily_quota INTEGER NOT NULL DEFAULT 3,
  ocr_daily_quota INTEGER NOT NULL DEFAULT 3,
  features JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TYPE subscription_status AS ENUM ('trialing','active','past_due','canceled','expired');

CREATE TABLE public.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  plan_id UUID NOT NULL REFERENCES public.subscription_plans(id) ON DELETE RESTRICT,
  status subscription_status NOT NULL DEFAULT 'trialing',
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ends_at TIMESTAMPTZ,
  auto_renew BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.ai_quotas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  feature_context VARCHAR(100) NOT NULL,
  daily_limit INTEGER NOT NULL,
  used_count INTEGER NOT NULL DEFAULT 0,
  window_date DATE NOT NULL DEFAULT CURRENT_DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_quota_day UNIQUE (profile_id, feature_context, window_date)
);

-- ---------------------------------------------------------------------------
-- Audit général et versioning
-- ---------------------------------------------------------------------------
CREATE TABLE public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_profile_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  action VARCHAR(100) NOT NULL,
  entity_type VARCHAR(100) NOT NULL,
  entity_id UUID,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.content_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type VARCHAR(100) NOT NULL,
  entity_id UUID NOT NULL,
  version INTEGER NOT NULL,
  snapshot JSONB NOT NULL,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_entity_version UNIQUE (entity_type, entity_id, version)
);

-- ---------------------------------------------------------------------------
-- Traçabilité IA manquante dans ai_audit_logs
-- ---------------------------------------------------------------------------
ALTER TABLE public.ai_audit_logs ADD COLUMN IF NOT EXISTS prompt_version VARCHAR(50);
ALTER TABLE public.ai_audit_logs ADD COLUMN IF NOT EXISTS prompt_hash TEXT;
ALTER TABLE public.ai_audit_logs ADD COLUMN IF NOT EXISTS confidence_score NUMERIC(4,3);
ALTER TABLE public.ai_audit_logs ADD COLUMN IF NOT EXISTS request_context JSONB NOT NULL DEFAULT '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- RLS deny-all sur les nouvelles tables
-- ---------------------------------------------------------------------------
ALTER TABLE public.teacher_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ocr_transcriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_corrections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.remediation_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spaced_repetition_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rag_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rag_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bem_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bem_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bem_session_answers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bem_readiness_estimates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_quotas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.content_versions ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- Index utiles
-- ---------------------------------------------------------------------------
CREATE INDEX idx_courses_chapter ON public.courses(chapter_id);
CREATE INDEX idx_lessons_course ON public.lessons(course_id);
CREATE INDEX idx_ocr_answer ON public.ocr_transcriptions(answer_id);
CREATE INDEX idx_ai_corrections_student ON public.ai_corrections(student_id);
CREATE INDEX idx_remediation_student ON public.remediation_assignments(student_id, status);
CREATE INDEX idx_spaced_student_due ON public.spaced_repetition_reviews(student_id, scheduled_for);
CREATE INDEX idx_rag_chunks_document ON public.rag_chunks(document_id);
CREATE INDEX idx_bem_sessions_student ON public.bem_sessions(student_id);
CREATE INDEX idx_bem_answers_session ON public.bem_session_answers(bem_session_id);
CREATE INDEX idx_notifications_recipient ON public.notifications(recipient_profile_id, read_at);
CREATE INDEX idx_subscriptions_profile ON public.subscriptions(profile_id, status);
CREATE INDEX idx_ai_quotas_profile_day ON public.ai_quotas(profile_id, window_date);
CREATE INDEX idx_audit_entity ON public.audit_logs(entity_type, entity_id);

-- ---------------------------------------------------------------------------
-- Triggers updated_at, réutilise la fonction de la migration initiale
-- ---------------------------------------------------------------------------
CREATE TRIGGER trg_teacher_profiles_updated_at BEFORE UPDATE ON public.teacher_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_courses_updated_at BEFORE UPDATE ON public.courses FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_lessons_updated_at BEFORE UPDATE ON public.lessons FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_rag_documents_updated_at BEFORE UPDATE ON public.rag_documents FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_subscriptions_updated_at BEFORE UPDATE ON public.subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_ai_quotas_updated_at BEFORE UPDATE ON public.ai_quotas FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();