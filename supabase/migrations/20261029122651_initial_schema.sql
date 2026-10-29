-- =============================================================================
-- SMARTCEM - MIGRATION 00001 : SCHÉMA RELATIONNEL COMPLET
-- Cycle Moyen Algérien (1AM - 4AM) & Moteur Adaptatif
-- =============================================================================

-- Extensions nécessaires
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- ENUMS SYSTÈME
-- -----------------------------------------------------------------------------
CREATE TYPE user_role AS ENUM ('super_admin', 'teacher', 'student', 'parent');
CREATE TYPE grade_code AS ENUM ('1AM', '2AM', '3AM', '4AM');
CREATE TYPE difficulty_level AS ENUM ('remediation', 'easy', 'medium', 'hard', 'bem_challenge');
CREATE TYPE content_status AS ENUM ('draft', 'review_pending', 'validated', 'archived');
CREATE TYPE exercise_mode AS ENUM ('diagnostic', 'formative', 'exam_bem', 'remediation');
CREATE TYPE answer_status AS ENUM ('correct', 'partially_correct', 'incorrect', 'unevaluable');
CREATE TYPE error_category AS ENUM (
  'sign_error',           -- Erreur de signe (+ / -)
  'arithmetic_calc',      -- Erreur de calcul de base
  'algorithmic_step',     -- Erreur dans l'ordre de la méthode (ex: algorithme d'Euclide)
  'math_property_violation', -- Propriété fausse (ex: √(a+b) = √a + √b)
  'reading_comprehension',-- Mauvaise lecture de la consigne
  'notation_formalism',   -- Mauvaise notation (fraction non simplifiée)
  'slip_inattention'      -- Inattention probable sur notion maîtrisée
);

-- =============================================================================
-- 1. IDENTITÉ & PROFILS UTILISATEURS
-- =============================================================================

-- Profil principal relié à la table d'authentification Supabase (auth.users)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role user_role NOT NULL DEFAULT 'student',
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    avatar_url TEXT,
    locale VARCHAR(5) NOT NULL DEFAULT 'fr' CHECK (locale IN ('fr', 'ar')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Profil spécifique pour les élèves
CREATE TABLE student_profiles (
    profile_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    grade_level grade_code NOT NULL,
    academic_year VARCHAR(9) NOT NULL DEFAULT '2024-2025',
    is_bem_candidate BOOLEAN GENERATED ALWAYS AS (grade_level = '4AM') STORED,
    current_streak_days INTEGER NOT NULL DEFAULT 0,
    total_xp INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Relation Parents <-> Enfants (étanchéité stricte)
CREATE TABLE parent_child_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    relationship_type VARCHAR(50) DEFAULT 'legal_guardian',
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_parent_student UNIQUE (parent_id, student_id)
);

-- Classes gérées par les enseignants
CREATE TABLE classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    grade_level grade_code NOT NULL,
    name VARCHAR(100) NOT NULL,
    academic_year VARCHAR(9) NOT NULL DEFAULT '2024-2025',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE class_enrollments (
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (class_id, student_id)
);

-- =============================================================================
-- 2. RÉFÉRENTIEL CURRICULUM OFFICIEL ALGÉRIEN & APC
-- =============================================================================

CREATE TABLE subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(20) NOT NULL UNIQUE, -- 'MATH', 'PHYS', 'ARABIC', etc.
    name_fr VARCHAR(100) NOT NULL,
    name_ar VARCHAR(100) NOT NULL,
    icon_name VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE domains (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    grade_level grade_code NOT NULL,
    code VARCHAR(50) NOT NULL, -- 'NUM_ACT' (Activités Numériques), 'GEO_ACT'
    title_fr VARCHAR(200) NOT NULL,
    title_ar VARCHAR(200) NOT NULL,
    order_index INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT unique_domain_grade UNIQUE (subject_id, grade_level, code)
);

CREATE TABLE chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    domain_id UUID NOT NULL REFERENCES domains(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL, -- 'CH1_NOMBRES_RATIONNELS_RADICAUX'
    title_fr VARCHAR(255) NOT NULL,
    title_ar VARCHAR(255) NOT NULL,
    description_fr TEXT,
    description_ar TEXT,
    order_index INTEGER NOT NULL DEFAULT 1,
    status content_status NOT NULL DEFAULT 'draft',
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE competencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chapter_id UUID NOT NULL REFERENCES chapters(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL UNIQUE, -- '4AM_MATH_C1_PGCD', '4AM_MATH_C2_RADICAL'
    title_fr VARCHAR(255) NOT NULL,
    title_ar VARCHAR(255) NOT NULL,
    description TEXT,
    order_index INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE apc_indicators (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    competency_id UUID NOT NULL REFERENCES competencies(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL, -- 'IND_EUCLIDE', 'IND_SUBTRACTION'
    description_fr TEXT NOT NULL,
    description_ar TEXT NOT NULL,
    weight NUMERIC(3, 2) NOT NULL DEFAULT 1.00 CHECK (weight > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- 3. EXERCICES, QUESTIONS, BARÈMES & ANIMATIONS
-- =============================================================================

CREATE TABLE exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chapter_id UUID NOT NULL REFERENCES chapters(id) ON DELETE RESTRICT,
    title_fr VARCHAR(255) NOT NULL,
    title_ar VARCHAR(255) NOT NULL,
    mode exercise_mode NOT NULL DEFAULT 'formative',
    difficulty difficulty_level NOT NULL DEFAULT 'medium',
    status content_status NOT NULL DEFAULT 'draft',
    estimated_time_minutes INTEGER NOT NULL DEFAULT 15,
    is_bem_standard BOOLEAN NOT NULL DEFAULT FALSE,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    competency_id UUID NOT NULL REFERENCES competencies(id) ON DELETE RESTRICT,
    order_index INTEGER NOT NULL DEFAULT 1,
    statement_fr TEXT NOT NULL,
    statement_ar TEXT NOT NULL,
    latex_content TEXT, -- Formules exactes (ex: \text{PGCD}(1053, 325))
    expected_answer_exact TEXT, -- Résultat exact déterministe (ex: "13")
    hint_level_1_fr TEXT, -- Indice méthodologique de départ
    hint_level_1_ar TEXT,
    hint_level_2_fr TEXT, -- Indice intermédiaire
    hint_level_2_ar TEXT,
    hint_level_3_fr TEXT, -- Indice complet
    hint_level_3_ar TEXT,
    method_summary_fr TEXT, -- Synthèse de la règle de cours
    method_summary_ar TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE rubrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    indicator_id UUID REFERENCES apc_indicators(id) ON DELETE SET NULL,
    criteria_name VARCHAR(150) NOT NULL, -- Ex: "Exactitude du quotient euclidien"
    max_points NUMERIC(4, 2) NOT NULL CHECK (max_points > 0),
    is_deterministic BOOLEAN NOT NULL DEFAULT TRUE, -- Vérifiable par calcul direct
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE step_solutions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    step_number INTEGER NOT NULL,
    title_fr VARCHAR(150) NOT NULL,
    title_ar VARCHAR(150) NOT NULL,
    explanation_fr TEXT NOT NULL,
    explanation_ar TEXT NOT NULL,
    latex_formula TEXT, -- Formule de l'étape animée (ex: 1053 = 325 \times 3 + 78)
    pause_duration_ms INTEGER NOT NULL DEFAULT 1500,
    order_index INTEGER NOT NULL DEFAULT 1,
    CONSTRAINT unique_step_question UNIQUE (question_id, step_number)
);

-- =============================================================================
-- 4. KNOWLEDGE TRACING (BKT), SOUMISSIONS & TAXONOMIE D'ERREURS
-- =============================================================================

CREATE TABLE submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE RESTRICT,
    mode exercise_mode NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    score_percentage NUMERIC(5, 2),
    time_spent_seconds INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES questions(id) ON DELETE RESTRICT,
    student_raw_input TEXT,
    scanned_image_url TEXT,
    transcribed_latex TEXT,
    ocr_confidence_score NUMERIC(3, 2),
    status answer_status NOT NULL DEFAULT 'unevaluable',
    points_awarded NUMERIC(4, 2) NOT NULL DEFAULT 0.00,
    hints_used_count INTEGER NOT NULL DEFAULT 0,
    method_viewed BOOLEAN NOT NULL DEFAULT FALSE,
    deterministic_validated BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE error_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    answer_id UUID NOT NULL REFERENCES answers(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    competency_id UUID NOT NULL REFERENCES competencies(id) ON DELETE RESTRICT,
    error_type error_category NOT NULL,
    detected_by VARCHAR(20) NOT NULL CHECK (detected_by IN ('deterministic_engine', 'ai_model')),
    context_snippet TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Matrice Cognitive BKT : Élève × Compétence
CREATE TABLE student_knowledge_states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    competency_id UUID NOT NULL REFERENCES competencies(id) ON DELETE RESTRICT,
    mastery_probability NUMERIC(4, 3) NOT NULL DEFAULT 0.100 CHECK (mastery_probability BETWEEN 0 AND 1), -- P(L_t)
    confidence_score NUMERIC(4, 3) NOT NULL DEFAULT 0.500,
    stability_factor NUMERIC(6, 2) NOT NULL DEFAULT 1.00, -- Intervalle répétition espacée (en jours)
    success_count INTEGER NOT NULL DEFAULT 0,
    failure_count INTEGER NOT NULL DEFAULT 0,
    consecutive_success INTEGER NOT NULL DEFAULT 0,
    last_evaluated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    next_review_due_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '1 day',
    CONSTRAINT unique_student_competency UNIQUE (student_id, competency_id)
);

-- =============================================================================
-- 5. AUDIT & MAÎTRISE DES COÛTS IA
-- =============================================================================

CREATE TABLE ai_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    feature_context VARCHAR(100) NOT NULL, -- 'exercise_correction', 'hint_generation', 'ocr_parsing'
    provider_name VARCHAR(50) NOT NULL,    -- 'google_gemini', 'groq', 'mistral'
    model_name VARCHAR(100) NOT NULL,      -- 'gemini-1.5-flash', 'llama-3.1-8b'
    prompt_tokens INTEGER NOT NULL DEFAULT 0,
    completion_tokens INTEGER NOT NULL DEFAULT 0,
    total_tokens INTEGER NOT NULL DEFAULT 0,
    cost_usd NUMERIC(8, 6) NOT NULL DEFAULT 0.000000,
    latency_ms INTEGER NOT NULL DEFAULT 0,
    cache_hit BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================================
-- INDEX DE PERFORMANCE CRITIQUES
-- =============================================================================

CREATE INDEX idx_student_profiles_grade ON student_profiles(grade_level);
CREATE INDEX idx_parent_child_lookup ON parent_child_links(parent_id, student_id);
CREATE INDEX idx_competencies_chapter ON competencies(chapter_id);
CREATE INDEX idx_questions_exercise ON questions(exercise_id);
CREATE INDEX idx_submissions_student ON submissions(student_id, exercise_id);
CREATE INDEX idx_knowledge_states_due ON student_knowledge_states(student_id, next_review_due_at);
CREATE INDEX idx_ai_audit_user_cost ON ai_audit_logs(user_id, created_at);

-- =============================================================================
-- TRIGGER UNIVERSEL : updated_at automatique
-- =============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_student_profiles_updated_at BEFORE UPDATE ON student_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER trg_exercises_updated_at BEFORE UPDATE ON exercises FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();