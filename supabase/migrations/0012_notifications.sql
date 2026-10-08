-- 0012: Notification system (like / comment / follow / tag)

CREATE TABLE notifications (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id uuid        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  sender_id    uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  type         text        NOT NULL CHECK (type IN ('like','comment','follow','tag')),
  activity_id  uuid        REFERENCES activities(id) ON DELETE CASCADE,
  is_read      boolean     NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX notifications_recipient_idx ON notifications(recipient_id, created_at DESC);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notif_select" ON notifications
  FOR SELECT TO authenticated USING (recipient_id = auth.uid());

CREATE POLICY "notif_update" ON notifications
  FOR UPDATE TO authenticated
  USING (recipient_id = auth.uid())
  WITH CHECK (recipient_id = auth.uid());

-- ── Trigger: like ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_on_like()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_author uuid;
BEGIN
  SELECT user_id INTO v_author FROM public.activities WHERE id = NEW.activity_id;
  IF v_author IS NULL OR v_author = NEW.user_id THEN RETURN NEW; END IF;
  INSERT INTO public.notifications (recipient_id, sender_id, type, activity_id)
    VALUES (v_author, NEW.user_id, 'like', NEW.activity_id);
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_notify_like
  AFTER INSERT ON activity_likes
  FOR EACH ROW EXECUTE FUNCTION notify_on_like();

-- ── Trigger: comment ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_on_comment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_author uuid;
BEGIN
  SELECT user_id INTO v_author FROM public.activities WHERE id = NEW.activity_id;
  IF v_author IS NULL OR v_author = NEW.user_id THEN RETURN NEW; END IF;
  INSERT INTO public.notifications (recipient_id, sender_id, type, activity_id)
    VALUES (v_author, NEW.user_id, 'comment', NEW.activity_id);
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_notify_comment
  AFTER INSERT ON activity_comments
  FOR EACH ROW EXECUTE FUNCTION notify_on_comment();

-- ── Trigger: follow ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_on_follow()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.notifications (recipient_id, sender_id, type)
    VALUES (NEW.followee_id, NEW.follower_id, 'follow');
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_notify_follow
  AFTER INSERT ON follows
  FOR EACH ROW EXECUTE FUNCTION notify_on_follow();

-- ── Trigger: tag ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_on_tag()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE v_tagger uuid;
BEGIN
  SELECT user_id INTO v_tagger FROM public.activities WHERE id = NEW.activity_id;
  IF v_tagger IS NULL OR v_tagger = NEW.tagged_user_id THEN RETURN NEW; END IF;
  INSERT INTO public.notifications (recipient_id, sender_id, type, activity_id)
    VALUES (NEW.tagged_user_id, v_tagger, 'tag', NEW.activity_id);
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_notify_tag
  AFTER INSERT ON activity_tags
  FOR EACH ROW EXECUTE FUNCTION notify_on_tag();
