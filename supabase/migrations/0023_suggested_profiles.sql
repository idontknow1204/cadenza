CREATE OR REPLACE FUNCTION get_suggested_profiles(p_user_id UUID)
RETURNS TABLE (
    id          UUID,
    real_name   TEXT,
    instrument  TEXT,
    major       TEXT,
    avatar_url  TEXT,
    reason      TEXT,
    shared_info TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    WITH
        my_schools AS (
            SELECT a.institution_name
            FROM affiliations a
            WHERE a.user_id = p_user_id
        ),
        my_cities AS (
            SELECT unnest(pr.home_cities) AS city
            FROM profiles pr
            WHERE pr.id = p_user_id
        ),
        already_related AS (
            SELECT f.followee_id AS other_id FROM follows f WHERE f.follower_id = p_user_id
            UNION
            SELECT f2.follower_id AS other_id FROM follows f2 WHERE f2.followee_id = p_user_id
        ),
        school_matches AS (
            SELECT DISTINCT a.user_id, 'school'::TEXT AS rsn, a.institution_name AS sinfo
            FROM affiliations a
            JOIN my_schools ms ON a.institution_name = ms.institution_name
            WHERE a.user_id <> p_user_id
        ),
        city_matches AS (
            SELECT DISTINCT pr2.id AS user_id, 'city'::TEXT AS rsn, mc.city AS sinfo
            FROM profiles pr2
            JOIN my_cities mc ON mc.city = ANY(pr2.home_cities)
            WHERE pr2.id <> p_user_id
        ),
        all_matches AS (
            SELECT * FROM school_matches
            UNION ALL
            SELECT * FROM city_matches
        )
    SELECT DISTINCT ON (p.id)
        p.id,
        p.real_name,
        p.instrument,
        p.major,
        p.avatar_url,
        m.rsn       AS reason,
        m.sinfo     AS shared_info
    FROM all_matches m
    JOIN profiles p ON p.id = m.user_id
    WHERE p.id NOT IN (SELECT ar.other_id FROM already_related ar)
      AND p.onboarding_complete = true
    ORDER BY p.id, (CASE WHEN m.rsn = 'school' THEN 0 ELSE 1 END)
    LIMIT 20;
END;
$$;
