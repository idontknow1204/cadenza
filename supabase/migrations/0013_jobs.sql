-- 0013: Jobs board (오디션·단원모집·레슨·연주의뢰)

CREATE TYPE job_type AS ENUM ('audition', 'position', 'lesson', 'gig');

CREATE TABLE jobs (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type         job_type    NOT NULL,
  title        text        NOT NULL CHECK (char_length(title) >= 2),
  organization text,
  location     text,
  instruments  text[]      NOT NULL DEFAULT '{}',
  description  text        NOT NULL CHECK (char_length(description) >= 10),
  requirements text,
  deadline     date,
  contact      text,
  is_active    boolean     NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX jobs_active_idx  ON jobs(is_active, created_at DESC);
CREATE INDEX jobs_type_idx    ON jobs(type);
CREATE INDEX jobs_user_idx    ON jobs(user_id);

ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "jobs_select" ON jobs FOR SELECT TO authenticated USING (true);
CREATE POLICY "jobs_insert" ON jobs FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "jobs_update" ON jobs FOR UPDATE TO authenticated USING (user_id = auth.uid());
CREATE POLICY "jobs_delete" ON jobs FOR DELETE TO authenticated USING (user_id = auth.uid());
