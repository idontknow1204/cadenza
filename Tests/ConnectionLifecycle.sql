-- Run inside a transaction; the caller rolls back the test users and all changes.
INSERT INTO auth.users(id, raw_user_meta_data) VALUES
 ('f0000000-0000-0000-0000-000000000001', '{"real_name":"Connection test A"}'),
 ('f0000000-0000-0000-0000-000000000002', '{"real_name":"Connection test B"}'),
 ('f0000000-0000-0000-0000-000000000003', '{"real_name":"Connection test outsider"}');

CREATE FUNCTION pg_temp.assert_true(ok boolean, message text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAILED: %', message; END IF; END $$;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'f0000000-0000-0000-0000-000000000001', true);
SELECT pg_temp.assert_true(public.transition_connection('f0000000-0000-0000-0000-000000000002', 'request')='requestSent', 'send');
SELECT pg_temp.assert_true(public.transition_connection('f0000000-0000-0000-0000-000000000002', 'request')='requestSent', 'duplicate send is idempotent');
SELECT set_config('request.jwt.claim.sub', 'f0000000-0000-0000-0000-000000000002', true);
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.notifications WHERE recipient_id=auth.uid() AND type='follow'), 'single notification');
SELECT pg_temp.assert_true(public.transition_connection('f0000000-0000-0000-0000-000000000001', 'request')='requestReceived', 'cross request does not create another edge');
SELECT pg_temp.assert_true(public.transition_connection('f0000000-0000-0000-0000-000000000001', 'accept')='connected', 'accept');
SELECT pg_temp.assert_true(public.transition_connection('f0000000-0000-0000-0000-000000000001', 'accept')='connected', 'repeated accept');
SELECT pg_temp.assert_true(NOT EXISTS(SELECT 1 FROM public.notifications WHERE recipient_id=auth.uid() AND type='follow' AND NOT is_read), 'accept marks request read');
SELECT pg_temp.assert_true(public.transition_connection('f0000000-0000-0000-0000-000000000001', 'decline')='connected', 'stale decline preserves accepted');
SELECT set_config('request.jwt.claim.sub', 'f0000000-0000-0000-0000-000000000001', true);
SELECT pg_temp.assert_true(public.transition_connection('f0000000-0000-0000-0000-000000000002', 'cancel')='connected', 'stale cancel preserves accepted');
SELECT pg_temp.assert_true((SELECT n=1 FROM public.connection_count(auth.uid())), 'one connected person');
SELECT pg_temp.assert_true(public.transition_connection('f0000000-0000-0000-0000-000000000002', 'disconnect')='none', 'disconnect');
SELECT public.transition_connection('f0000000-0000-0000-0000-000000000002', 'request');
SELECT pg_temp.assert_true(public.transition_connection('f0000000-0000-0000-0000-000000000002', 'cancel')='none', 'cancel');
SELECT set_config('request.jwt.claim.sub', 'f0000000-0000-0000-0000-000000000002', true);
DO $$ BEGIN
  BEGIN
    PERFORM public.transition_connection('f0000000-0000-0000-0000-000000000001', 'accept');
    RAISE EXCEPTION 'FAILED: cancelled request accepted';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM != 'This connection request is no longer pending' THEN RAISE; END IF;
  END;
END $$;
SELECT set_config('request.jwt.claim.sub', 'f0000000-0000-0000-0000-000000000001', true);
SELECT public.transition_connection('f0000000-0000-0000-0000-000000000002', 'request');
SELECT set_config('request.jwt.claim.sub', 'f0000000-0000-0000-0000-000000000003', true);
DO $$ BEGIN
  BEGIN
    PERFORM public.transition_connection('f0000000-0000-0000-0000-000000000001', 'accept');
    RAISE EXCEPTION 'FAILED: outsider accepted request';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM != 'This connection request is no longer pending' THEN RAISE; END IF;
  END;
END $$;
SELECT set_config('request.jwt.claim.sub', 'f0000000-0000-0000-0000-000000000002', true);
SELECT pg_temp.assert_true(public.transition_connection('f0000000-0000-0000-0000-000000000001', 'decline')='none', 'decline');
SELECT set_config('request.jwt.claim.sub', 'f0000000-0000-0000-0000-000000000001', true);
SELECT pg_temp.assert_true(public.transition_connection('f0000000-0000-0000-0000-000000000002', 'request')='requestSent', 'resend after decline');
RESET ROLE;
-- Simulate legacy reciprocal accepted/pending rows without modifying real users.
UPDATE public.follows SET status='accepted' WHERE follower_id='f0000000-0000-0000-0000-000000000001';
INSERT INTO public.follows(follower_id, followee_id, status) VALUES
 ('f0000000-0000-0000-0000-000000000002', 'f0000000-0000-0000-0000-000000000001', 'accepted');
SELECT pg_temp.assert_true((SELECT n=1 FROM public.connection_count('f0000000-0000-0000-0000-000000000001')), 'deduplicate legacy count');
SELECT pg_temp.assert_true((SELECT count(*)=1 FROM public.get_connections('f0000000-0000-0000-0000-000000000001')), 'deduplicate legacy list');
SELECT 'Connection lifecycle assertions passed' AS result;
