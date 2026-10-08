-- 0017_organizations.sql
-- Organization pages: orchestra, school, label, venue, agency, other.
-- Members can post activities under an org name; anyone can follow orgs.

-- 1. Organizations table
CREATE TABLE public.organizations (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT        NOT NULL,
    handle      TEXT        UNIQUE NOT NULL,
    description TEXT,
    logo_url    TEXT,
    website     TEXT,
    category    TEXT        NOT NULL DEFAULT 'other'
                CHECK (category IN ('orchestra','school','label','venue','agency','other')),
    created_by  UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Admins (owner = creator, admin = invited)
CREATE TABLE public.org_admins (
    org_id  UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id)      ON DELETE CASCADE,
    role    TEXT NOT NULL DEFAULT 'admin' CHECK (role IN ('owner', 'admin')),
    PRIMARY KEY (org_id, user_id)
);

-- 3. Follows
CREATE TABLE public.org_follows (
    org_id     UUID        NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id    UUID        NOT NULL REFERENCES public.profiles(id)      ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (org_id, user_id)
);

-- 4. Link activities to an org (nullable)
ALTER TABLE public.activities
    ADD COLUMN IF NOT EXISTS org_id UUID REFERENCES public.organizations(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS org_admins_user_idx ON public.org_admins (user_id);
CREATE INDEX IF NOT EXISTS org_follows_user_idx ON public.org_follows (user_id);
CREATE INDEX IF NOT EXISTS activities_org_idx   ON public.activities (org_id);

-- 5. RLS
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.org_admins    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.org_follows   ENABLE ROW LEVEL SECURITY;

CREATE POLICY orgs_select ON public.organizations FOR SELECT TO authenticated USING (true);
CREATE POLICY orgs_insert ON public.organizations FOR INSERT TO authenticated
    WITH CHECK (created_by = auth.uid());
CREATE POLICY orgs_update ON public.organizations FOR UPDATE TO authenticated
    USING (EXISTS (SELECT 1 FROM public.org_admins WHERE org_id = id AND user_id = auth.uid()));
CREATE POLICY orgs_delete ON public.organizations FOR DELETE TO authenticated
    USING (created_by = auth.uid());

CREATE POLICY org_admins_select ON public.org_admins FOR SELECT TO authenticated
    USING (user_id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.org_admins oa
                   WHERE oa.org_id = org_id AND oa.user_id = auth.uid()));
CREATE POLICY org_admins_insert ON public.org_admins FOR INSERT TO authenticated
    WITH CHECK (EXISTS (SELECT 1 FROM public.org_admins oa
                        WHERE oa.org_id = org_id AND oa.user_id = auth.uid()
                          AND oa.role = 'owner'));
CREATE POLICY org_admins_delete ON public.org_admins FOR DELETE TO authenticated
    USING (user_id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.org_admins oa
                   WHERE oa.org_id = org_id AND oa.user_id = auth.uid()
                     AND oa.role = 'owner'));

CREATE POLICY org_follows_select ON public.org_follows FOR SELECT TO authenticated USING (true);
CREATE POLICY org_follows_insert ON public.org_follows FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());
CREATE POLICY org_follows_delete ON public.org_follows FOR DELETE TO authenticated
    USING (user_id = auth.uid());

-- 6. Allow org admins to post activities on behalf of org
-- The existing activities_insert policy checks user_id = auth.uid() which still holds.
-- We just add: org_id must be an org the user admins (or null).
DROP POLICY IF EXISTS activities_insert ON activities;
CREATE POLICY activities_insert ON activities
    FOR INSERT TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND (
            org_id IS NULL
            OR EXISTS (SELECT 1 FROM public.org_admins WHERE org_id = activities.org_id AND user_id = auth.uid())
        )
    );

-- 7. Updated social_feed — deduplicated by priority, includes org follows
-- Must DROP first because return type changes (adding 'org jsonb' column)
DROP FUNCTION IF EXISTS social_feed(uuid);
CREATE FUNCTION social_feed(p_user_id uuid)
RETURNS TABLE (
    id            uuid,
    user_id       uuid,
    type          text,
    title         text,
    activity_date text,
    location      text,
    role          text,
    program       text,
    prize         text,
    organizer     text,
    image_urls    text[],
    verification  text,
    author        jsonb,
    org           jsonb,
    feed_reason   text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH
  my_connections AS (
    SELECT followee_id AS connection_id FROM follows
    WHERE follower_id = p_user_id AND status = 'accepted'
    UNION
    SELECT follower_id AS connection_id FROM follows
    WHERE followee_id = p_user_id AND status = 'accepted'
  ),
  my_org_follows AS (
    SELECT org_id FROM org_follows WHERE user_id = p_user_id
  ),
  own_ids AS (
    SELECT id FROM activities WHERE user_id = p_user_id
  ),
  following_ids AS (
    SELECT a.id FROM activities a
    JOIN my_connections c ON a.user_id = c.connection_id
    WHERE a.visibility::text != 'private'
  ),
  connection_commented_ids AS (
    SELECT DISTINCT a.id FROM activities a
    JOIN activity_comments ac ON ac.activity_id = a.id
    JOIN my_connections c      ON ac.user_id = c.connection_id
    WHERE a.user_id != p_user_id
      AND ac.user_id != p_user_id
      AND a.visibility::text IN ('public', 'industry_followers')
  ),
  seed_ids AS (
    SELECT a.id FROM activities a
    JOIN profiles p ON a.user_id = p.id
    WHERE p.is_seed = true
      AND a.visibility::text != 'private'
  ),
  org_ids AS (
    SELECT a.id FROM activities a
    JOIN my_org_follows f ON a.org_id = f.org_id
    WHERE a.visibility::text != 'private'
  ),
  -- Merge, dedup by priority (own > following > org > seed > connection_commented)
  all_ids AS (
    SELECT id, 'own'                  AS reason, 1 AS priority FROM own_ids
    UNION ALL SELECT id, 'following',            2 FROM following_ids
    UNION ALL SELECT id, 'org',                  3 FROM org_ids
    UNION ALL SELECT id, 'seed',                 4 FROM seed_ids
    UNION ALL SELECT id, 'connection_commented', 5 FROM connection_commented_ids
  ),
  feed AS (
    SELECT DISTINCT ON (id) id, reason
    FROM all_ids
    ORDER BY id, priority
  )
  SELECT
    a.id,
    a.user_id,
    a.type::text,
    a.title,
    a.activity_date::text,
    a.location,
    a.role,
    a.program,
    a.prize,
    a.organizer,
    a.image_urls,
    a.verification::text,
    jsonb_build_object('id', p.id, 'real_name', p.real_name, 'instrument', p.instrument) AS author,
    CASE WHEN a.org_id IS NOT NULL THEN
      jsonb_build_object('id', o.id, 'name', o.name, 'logo_url', o.logo_url, 'category', o.category)
    ELSE NULL END AS org,
    f.reason AS feed_reason
  FROM feed f
  JOIN activities   a ON a.id = f.id
  JOIN profiles     p ON a.user_id = p.id
  LEFT JOIN organizations o ON a.org_id = o.id
  ORDER BY a.created_at DESC
  LIMIT 100;
$$;
