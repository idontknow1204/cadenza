import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { url } = await req.json();

    if (!url || !url.includes("instagram.com")) {
      return new Response(
        JSON.stringify({ error: "Instagram URL을 입력해주세요" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const appToken = Deno.env.get("FACEBOOK_APP_TOKEN");
    if (!appToken) {
      return new Response(
        JSON.stringify({ error: "서버 설정이 필요합니다 (FACEBOOK_APP_TOKEN)" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const oembedUrl =
      `https://graph.facebook.com/v21.0/instagram_oembed` +
      `?url=${encodeURIComponent(url)}` +
      `&access_token=${appToken}` +
      `&fields=title,author_name,thumbnail_url`;

    const res = await fetch(oembedUrl);
    const data = await res.json();

    if (data.error) {
      const msg =
        data.error.code === 100
          ? "공개 게시물만 가져올 수 있습니다"
          : data.error.message ?? "게시물을 가져올 수 없습니다";
      return new Response(JSON.stringify({ error: msg }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({
        caption: data.title ?? "",
        authorName: data.author_name ?? "",
        thumbnailUrl: data.thumbnail_url ?? null,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
