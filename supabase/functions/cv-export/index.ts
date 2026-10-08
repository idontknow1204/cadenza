// cv-export — Fermata CV: canonical JSON 어셈블리 + PDF 렌더/캐시
//
//   POST  (Authorization: Bearer <user JWT>)  → 로그인 사용자 CV PDF 의 signed URL
//         cv/{slug}/{cv_version}.pdf 캐시 히트면 렌더 생략
//   GET   ?slug=jihoon-kim                     → 공개 웹 프로필용 리댁션 JSON
//
// 매핑은 SQL(cv_data / cv_data_by_slug), PDF 픽셀은 render-service 가 담당. 이 함수는 오케스트레이션.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RENDER_SERVICE_URL = Deno.env.get("RENDER_SERVICE_URL")!; // 예: http://render:8080
const RENDER_TOKEN = Deno.env.get("RENDER_TOKEN")!;
const SIGNED_TTL = 60 * 60; // 1h

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    // ---- 공개 웹 프로필 데이터: GET ?slug= -----------------------------
    if (req.method === "GET") {
      const slug = new URL(req.url).searchParams.get("slug");
      if (!slug) return json({ error: "slug required" }, 400);
      const anon = createClient(SUPABASE_URL, ANON_KEY);
      const { data, error } = await anon.rpc("cv_data_by_slug", { p_slug: slug });
      if (error) return json({ error: error.message }, 500);
      if (!data) return json({ error: "profile not found" }, 404);
      return json({ data });
    }

    // ---- 인증 사용자 PDF: POST -----------------------------------------
    if (req.method === "POST") {
      const authHeader = req.headers.get("Authorization");
      if (!authHeader) return json({ error: "unauthorized" }, 401);

      const userClient = createClient(SUPABASE_URL, ANON_KEY, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: u, error: uErr } = await userClient.auth.getUser();
      if (uErr || !u?.user) return json({ error: "unauthorized" }, 401);
      const uid = u.user.id;

      const svc = createClient(SUPABASE_URL, SERVICE_KEY);

      // 캐시 키: slug + cv_version
      const { data: prof, error: pErr } = await svc
        .from("profiles").select("slug, cv_version").eq("id", uid).single();
      if (pErr || !prof) return json({ error: "profile not found" }, 404);
      const key = `${prof.slug}/${prof.cv_version}.pdf`;

      // 캐시 히트?
      const { data: listed } = await svc.storage.from("cv")
        .list(prof.slug, { search: `${prof.cv_version}.pdf` });
      if (!listed?.some((f) => f.name === `${prof.cv_version}.pdf`)) {
        // 미스 → 전체(민감정보 포함) JSON 조립 → render-service → 업로드
        const { data: cv, error: cvErr } = await svc.rpc("cv_data", {
          p_profile: uid, p_public: false,
        });
        if (cvErr || !cv) return json({ error: cvErr?.message ?? "no data" }, 500);

        const pdfResp = await fetch(`${RENDER_SERVICE_URL}/render`, {
          method: "POST",
          headers: { "Content-Type": "application/json", "x-render-token": RENDER_TOKEN },
          body: JSON.stringify(cv),
        });
        if (!pdfResp.ok) {
          return json({ error: `render failed: ${await pdfResp.text()}` }, 502);
        }
        const pdf = new Uint8Array(await pdfResp.arrayBuffer());
        const { error: upErr } = await svc.storage.from("cv")
          .upload(key, pdf, { contentType: "application/pdf", upsert: true });
        if (upErr) return json({ error: `upload failed: ${upErr.message}` }, 500);
      }

      const { data: signed, error: sErr } = await svc.storage.from("cv")
        .createSignedUrl(key, SIGNED_TTL);
      if (sErr || !signed) return json({ error: sErr?.message ?? "sign failed" }, 500);

      return json({ url: signed.signedUrl, version: prof.cv_version });
    }

    return json({ error: "method not allowed" }, 405);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
