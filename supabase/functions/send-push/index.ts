// send-push — APNs 푸시 알림 발송
//
//   notifications 테이블 INSERT 트리거 → DB 함수 → 이 Edge Function 호출
//
//   필수 Supabase Secrets (Dashboard → Settings → Edge Functions):
//     APNS_KEY_ID        — Apple Developer 에서 발급한 APNs Key ID (10자리)
//     APNS_TEAM_ID       — Apple Developer Team ID (10자리)
//     APNS_PRIVATE_KEY   — .p8 파일 내용 (-----BEGIN PRIVATE KEY----- 포함 전체)
//     APNS_BUNDLE_ID     — 앱 번들 ID (기본값: com.cadenza.app.kkiri-coporation)
//     APNS_PRODUCTION    — "true" 이면 프로덕션 APNs, 그 외 개발용 APNs
//
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY 는 Supabase 가 자동 주입

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const APNS_KEY_ID     = Deno.env.get("APNS_KEY_ID") ?? "";
const APNS_TEAM_ID    = Deno.env.get("APNS_TEAM_ID") ?? "";
const APNS_PRIVATE_KEY= Deno.env.get("APNS_PRIVATE_KEY") ?? "";
const APNS_BUNDLE_ID  = Deno.env.get("APNS_BUNDLE_ID") ?? "com.cadenza.app.kkiri-coporation";
const APNS_PRODUCTION = Deno.env.get("APNS_PRODUCTION") === "true";
const APNS_HOST       = APNS_PRODUCTION
  ? "https://api.push.apple.com"
  : "https://api.development.push.apple.com";

const SUPABASE_URL  = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY   = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

// ── APNs JWT (ES256) ────────────────────────────────────────────────────────

let jwtCache: { token: string; exp: number } | null = null;

async function getApnsJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (jwtCache && now < jwtCache.exp) return jwtCache.token;

  const toB64Url = (buf: ArrayBuffer) =>
    btoa(String.fromCharCode(...new Uint8Array(buf)))
      .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  const enc = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");

  const sigInput = `${enc({ alg: "ES256", kid: APNS_KEY_ID })}.${enc({ iss: APNS_TEAM_ID, iat: now })}`;

  const pemBody = APNS_PRIVATE_KEY
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(sigInput),
  );

  const token = `${sigInput}.${toB64Url(sig)}`;
  jwtCache = { token, exp: now + 3000 }; // 50분 캐시 (APNs JWT 유효기간 1시간)
  return token;
}

// ── 단일 토큰 전송 ────────────────────────────────────────────────────────────

async function sendToDevice(
  deviceToken: string,
  title: string,
  body: string,
): Promise<{ ok: boolean; stale: boolean }> {
  try {
    const jwt = await getApnsJWT();
    const res = await fetch(`${APNS_HOST}/3/device/${deviceToken}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic":     APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority":  "10",
        "content-type":   "application/json",
      },
      body: JSON.stringify({
        aps: { alert: { title, body }, badge: 1, sound: "default" },
      }),
    });
    // 410 = Unregistered (만료된 토큰), 400 = BadDeviceToken
    if (res.status === 410 || res.status === 400) return { ok: false, stale: true };
    return { ok: res.ok, stale: false };
  } catch {
    return { ok: false, stale: false };
  }
}

// ── 알림 타입별 메시지 ─────────────────────────────────────────────────────────

function notifText(type: string, name: string): { title: string; body: string } {
  const n = name || "누군가";
  switch (type) {
    case "like":    return { title: "Cadenza", body: `${n}님이 게시글을 좋아합니다` };
    case "comment": return { title: "Cadenza", body: `${n}님이 댓글을 남겼습니다` };
    case "follow":  return { title: "Cadenza", body: `${n}님이 연결을 요청했습니다` };
    case "tag":     return { title: "Cadenza", body: `${n}님이 게시글에 태그했습니다` };
    default:        return { title: "Cadenza", body: `${n}님의 새 알림` };
  }
}

// ── 메인 핸들러 ───────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  if (!APNS_KEY_ID || !APNS_TEAM_ID || !APNS_PRIVATE_KEY) {
    return json({ error: "APNs secrets not configured" }, 503);
  }

  const body = await req.json().catch(() => null);
  const { recipient_id, type, sender_name } = body ?? {};
  if (!recipient_id || !type) {
    return json({ error: "recipient_id and type required" }, 400);
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_KEY);
  const { data: tokens } = await supabase
    .from("push_tokens")
    .select("id, token")
    .eq("user_id", recipient_id)
    .eq("platform", "ios");

  if (!tokens?.length) return json({ sent: 0 });

  const { title, body: notifBody } = notifText(type, sender_name ?? "");
  const staleIds: string[] = [];

  await Promise.all(
    tokens.map(async ({ id, token }: { id: string; token: string }) => {
      const res = await sendToDevice(token, title, notifBody);
      if (res.stale) staleIds.push(id);
    }),
  );

  if (staleIds.length > 0) {
    await supabase.from("push_tokens").delete().in("id", staleIds);
  }

  return json({ sent: tokens.length - staleIds.length });
});
