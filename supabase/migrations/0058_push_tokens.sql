-- 0058: push_tokens — APNs 디바이스 토큰 저장
--   사용자당 여러 기기(아이폰 + 아이패드) 지원을 위해 (user_id, token) 복합 유니크.
--   platform 컬럼: Android 지원 시 'android' 추가 예정.

CREATE TABLE public.push_tokens (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token      text        NOT NULL,
  platform   text        NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios', 'android')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, token)
);

CREATE INDEX push_tokens_user_idx ON public.push_tokens(user_id);

ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

-- 본인 토큰만 읽기/쓰기/삭제 가능
CREATE POLICY "push_tokens_own" ON public.push_tokens
  FOR ALL TO authenticated
  USING  (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- service_role 은 RLS 우회 → Edge Function 에서 조회/삭제 가능
