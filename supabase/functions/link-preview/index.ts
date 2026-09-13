const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function decodeHtml(value: string): string {
  return value
    .replaceAll("&amp;", "&")
    .replaceAll("&quot;", '"')
    .replaceAll("&#39;", "'")
    .replaceAll("&#x27;", "'")
    .replaceAll("&lt;", "<")
    .replaceAll("&gt;", ">");
}

function metaContent(html: string, key: string): string {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

  const patterns = [
    new RegExp(
      `<meta[^>]+(?:property|name)=["']${escaped}["'][^>]+content=["']([^"']*)["'][^>]*>`,
      "i",
    ),
    new RegExp(
      `<meta[^>]+content=["']([^"']*)["'][^>]+(?:property|name)=["']${escaped}["'][^>]*>`,
      "i",
    ),
  ];

  for (const pattern of patterns) {
    const match = html.match(pattern);

    if (match?.[1]) {
      return decodeHtml(match[1].trim());
    }
  }

  return "";
}

function pageTitle(html: string): string {
  const match = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);

  if (!match?.[1]) {
    return "";
  }

  return decodeHtml(
    match[1]
      .replace(/\s+/g, " ")
      .trim(),
  );
}

function absoluteUrl(value: string, pageUrl: string): string {
  if (!value) {
    return "";
  }

  try {
    return new URL(value, pageUrl).toString();
  } catch (_) {
    return value;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    const body = await req.json();
    const rawUrl = typeof body?.url === "string" ? body.url.trim() : "";

    if (!rawUrl) {
      return new Response(
        JSON.stringify({
          error: "Missing URL",
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const uri = new URL(rawUrl);

    if (uri.protocol !== "http:" && uri.protocol !== "https:") {
      throw new Error("Unsupported URL scheme");
    }

    const response = await fetch(uri.toString(), {
      redirect: "follow",
      headers: {
        "User-Agent":
          "Mozilla/5.0 (compatible; 999WellnessLinkPreview/1.0)",
        Accept:
          "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      },
    });

    if (!response.ok) {
      throw new Error(`Remote page returned ${response.status}`);
    }

    const html = await response.text();
    const finalUrl = response.url || uri.toString();

    const title =
      metaContent(html, "og:title") ||
      metaContent(html, "twitter:title") ||
      pageTitle(html);

    const description =
      metaContent(html, "og:description") ||
      metaContent(html, "twitter:description") ||
      metaContent(html, "description");

    const image = absoluteUrl(
      metaContent(html, "og:image") ||
        metaContent(html, "twitter:image") ||
        metaContent(html, "twitter:image:src"),
      finalUrl,
    );

    const siteName =
      metaContent(html, "og:site_name") ||
      new URL(finalUrl).hostname.replace(/^www\./i, "");

    return new Response(
      JSON.stringify({
        url: finalUrl,
        title,
        description,
        image,
        siteName,
      }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
          "Cache-Control": "public, max-age=900",
        },
      },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }
});
