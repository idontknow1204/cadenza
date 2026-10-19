-- 0059: notifications 테이블 INSERT 시 APNs 푸시 알림 발송
--
--   pg_net 을 이용해 send-push Edge Function 을 비동기 호출.
--   push 실패가 주 트랜잭션을 절대 블록하지 않도록 EXCEPTION WHEN OTHERS 처리.
--
--   배포 후 Supabase Dashboard → SQL Editor 에서 아래 명령 1회 실행 필요:
--     SELECT vault.create_secret('<SERVICE_ROLE_KEY>', 'push_service_key');
--   (SERVICE_ROLE_KEY: Dashboard → Settings → API → service_role)

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION public.push_on_notification()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public, extensions, vault, pgsodium'
AS $$
DECLARE
  v_sender_name text;
  v_key         text;
BEGIN
  -- Vault 에서 service role key 조회 (미등록 시 조용히 종료)
  SELECT decrypted_secret INTO v_key
    FROM vault.decrypted_secrets
    WHERE name = 'push_service_key'
    LIMIT 1;

  IF v_key IS NULL OR v_key = '' THEN RETURN NEW; END IF;

  -- 발신자 이름 조회
  IF NEW.sender_id IS NOT NULL THEN
    SELECT real_name INTO v_sender_name
      FROM public.profiles WHERE id = NEW.sender_id;
  END IF;

  -- Edge Function 비동기 호출 (응답을 기다리지 않음)
  PERFORM net.http_post(
    url     := 'https://vcxllrzpolymzylrfscb.supabase.co/functions/v1/send-push',
    body    := jsonb_build_object(
                 'recipient_id', NEW.recipient_id,
                 'type',         NEW.type,
                 'sender_name',  COALESCE(v_sender_name, '')
               ),
    headers := jsonb_build_object(
                 'Content-Type',  'application/json',
                 'Authorization', 'Bearer ' || v_key
               )
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW; -- push 오류가 알림 저장을 막지 않도록
END;
$$;

DROP TRIGGER IF EXISTS trg_push_on_notification ON public.notifications;
CREATE TRIGGER trg_push_on_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.push_on_notification();
