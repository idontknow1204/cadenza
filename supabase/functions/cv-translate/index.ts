// cv-translate — 한국어 CV 항목 필드를 영어로 번역 제안 (Claude Messages API)
//
//   POST (Authorization: Bearer <user JWT>)
//   body: { kind: "performance"|"competition"|"masterclass"|"education", fields: {key: "원문", ...} }
//   → { translations: {key: "English", ...} }
//
// 사용자 편집 전 "제안"을 채우는 용도. 인증 필수(열린 번역 프록시 방지).
// 비밀: ANTHROPIC_API_KEY (필수), ANTHROPIC_MODEL (선택, 기본 claude-opus-4-8).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
// 항목별 짧은 번역 — 가장 낮은(저렴·빠른) Haiku 4.5 기본. ANTHROPIC_MODEL 로 상향 가능.
const MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-haiku-4-5";

const LANG_NAME: Record<string, string> = { en: "English", de: "German" };

function systemPrompt(targetLang: string): string {
  const name = LANG_NAME[targetLang] ?? "English";
  return `You translate fields of a Korean classical-musician's CV into ${name} for an editorial résumé.

Rules:
- Use the standard, widely-recognized ${name} name for institutions, orchestras, competitions, concert halls, festivals, and places. Examples (English): 예술의전당 → Seoul Arts Center; 한국예술종합학교 → Korea National University of Arts; 퀸 엘리자베스 콩쿠르 → Queen Elisabeth Competition; 서울시립교향악단 → Seoul Philharmonic Orchestra. Use the proper ${name} exonym where one is established (e.g. German: "바이올린" → "Violine"; "뮌헨" → "München"). If no established ${name} name exists, transliterate naturally in Title Case.
- Romanize personal names with Revised Romanization, given name first (김도현 → Dohyun Kim).
- Keep musical work titles in their conventional international form in ${name} (composer — work).
- Translate competition results/prizes to standard ${name}.
- Be concise. No explanations, no notes.
- If a value is already in ${name}, return it unchanged.

Respond with ONLY a JSON object mapping each input key to its translated ${name} string. No prose, no code fences.`;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

function extractJson(text: string): Record<string, string> {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end === -1) throw new Error("no JSON in model output");
  return JSON.parse(text.slice(start, end + 1));
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  try {
    // 인증 — 열린 번역 프록시 방지
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "unauthorized" }, 401);
    const client = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: u, error: uErr } = await client.auth.getUser();
    if (uErr || !u?.user) return json({ error: "unauthorized" }, 401);

    const { kind, fields, targetLang } = await req.json();
    const lang = targetLang === "de" ? "de" : "en";
    const entries = Object.entries(fields ?? {}).filter(
      ([, v]) => typeof v === "string" && v.trim().length > 0,
    );
    if (entries.length === 0) return json({ translations: {} });
    const clean = Object.fromEntries(entries);

    const body: Record<string, unknown> = {
      model: MODEL,
      max_tokens: 1024,
      system: systemPrompt(lang),
      messages: [
        {
          role: "user",
          content: `Entry type: ${kind ?? "performance"}\nFields (JSON):\n${JSON.stringify(clean)}`,
        },
      ],
    };
    // effort 는 Opus/Sonnet-4.6 전용 — Haiku 4.5 에 보내면 400. 지원 모델에만 추가.
    if (MODEL.startsWith("claude-opus") || MODEL === "claude-sonnet-4-6") {
      body.output_config = { effort: "low" };
    }

    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(body),
    });

    if (!resp.ok) {
      return json({ error: `anthropic ${resp.status}: ${await resp.text()}` }, 502);
    }
    const data = await resp.json();
    const text = (data.content ?? []).find((b: { type: string }) => b.type === "text")?.text ?? "";
    const translations = extractJson(text);
    return json({ translations });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
