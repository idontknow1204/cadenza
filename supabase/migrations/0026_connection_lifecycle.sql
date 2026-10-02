-- Serialize all transitions for a pair, and never confuse pending with accepted.
CREATE OR REPLACE FUNCTION public.transition_connection(p_other uuid, p_action text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  me uuid := auth.uid();
  has_accepted boolean;
BEGIN
  IF me IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501'; END IF;
  IF p_other IS NULL OR p_other = me THEN RAISE EXCEPTION 'Invalid recipient'; END IF;
  IF p_action NOT IN ('request', 'accept', 'decline', 'cancel', 'disconnect') OR p_action IS NULL THEN
    RAISE EXCEPTION 'Invalid connection action';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    least(me::text, p_other::text) || ':' || greatest(me::text, p_other::text), 0));
  SELECT EXISTS (SELECT 1 FROM public.follows WHERE status = 'accepted' AND
    ((follower_id = me AND followee_id = p_other) OR (follower_id = p_other AND followee_id = me))) INTO has_accepted;

  IF p_action = 'request' THEN
    IF NOT has_accepted AND NOT EXISTS (SELECT 1 FROM public.follows WHERE
      (follower_id = me AND followee_id = p_other) OR (follower_id = p_other AND followee_id = me)) THEN
      INSERT INTO public.follows(follower_id, followee_id, status) VALUES (me, p_other, 'pending');
    END IF;
  ELSIF p_action = 'accept' THEN
    IF NOT has_accepted THEN
      UPDATE public.follows SET status = 'accepted'
        WHERE follower_id = p_other AND followee_id = me AND status = 'pending';
      IF NOT FOUND THEN RAISE EXCEPTION 'This connection request is no longer pending'; END IF;
    END IF;
    -- Legacy reciprocal pending rows must not survive an acceptance.
    DELETE FROM public.follows WHERE status = 'pending' AND
      ((follower_id = me AND followee_id = p_other) OR (follower_id = p_other AND followee_id = me));
  ELSIF p_action = 'decline' THEN
    DELETE FROM public.follows WHERE follower_id = p_other AND followee_id = me AND status = 'pending';
  ELSIF p_action = 'cancel' THEN
    DELETE FROM public.follows WHERE follower_id = me AND followee_id = p_other AND status = 'pending';
  ELSE
    DELETE FROM public.follows WHERE
      (follower_id = me AND followee_id = p_other) OR (follower_id = p_other AND followee_id = me);
  END IF;

  IF EXISTS (SELECT 1 FROM public.follows WHERE status = 'accepted' AND
    ((follower_id = me AND followee_id = p_other) OR (follower_id = p_other AND followee_id = me))) THEN RETURN 'connected'; END IF;
  IF EXISTS (SELECT 1 FROM public.follows WHERE follower_id = p_other AND followee_id = me AND status = 'pending') THEN RETURN 'requestReceived'; END IF;
  IF EXISTS (SELECT 1 FROM public.follows WHERE follower_id = me AND followee_id = p_other AND status = 'pending') THEN RETURN 'requestSent'; END IF;
  RETURN 'none';
END;
$$;
REVOKE ALL ON FUNCTION public.transition_connection(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.transition_connection(uuid, text) TO authenticated;

-- Keep historical notification records, but do not leave handled requests unread.
CREATE OR REPLACE FUNCTION public.read_resolved_connection_notification()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF TG_OP = 'DELETE' OR NEW.status = 'accepted' THEN
    UPDATE public.notifications SET is_read = true WHERE type = 'follow'
      AND sender_id = OLD.follower_id AND recipient_id = OLD.followee_id AND NOT is_read;
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_resolve_connection_notification AFTER UPDATE OF status OR DELETE ON public.follows
  FOR EACH ROW EXECUTE FUNCTION public.read_resolved_connection_notification();

-- Old seed data can contain accepted edges in both directions; count people once.
CREATE OR REPLACE FUNCTION public.connection_count(p_user_id uuid)
RETURNS TABLE(n bigint) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT count(DISTINCT CASE WHEN follower_id = p_user_id THEN followee_id ELSE follower_id END)
  FROM public.follows WHERE (follower_id = p_user_id OR followee_id = p_user_id) AND status = 'accepted';
$$;
CREATE OR REPLACE FUNCTION public.get_connections(p_user_id uuid)
RETURNS TABLE(id uuid, real_name text, instrument text, major text, avatar_url text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT DISTINCT p.id, p.real_name, p.instrument, p.major, p.avatar_url
  FROM public.follows f JOIN public.profiles p ON
    ((f.follower_id = p_user_id AND p.id = f.followee_id) OR (f.followee_id = p_user_id AND p.id = f.follower_id))
  WHERE f.status = 'accepted' ORDER BY p.real_name;
$$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'follows') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.follows;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;
