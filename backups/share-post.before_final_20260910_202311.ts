import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(
  supabaseUrl,
  serviceRoleKey,
);

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const postId = url.searchParams.get("post")?.trim() ?? "";

  const appUrl = postId.length > 0
    ? `https://wellness.999intelligence.io/?post=${encodeURIComponent(postId)}`
    : "https://wellness.999intelligence.io/";

  let authorName = "999 Wellness";
  let body = "Share wellness. Grow the community.";
  let mediaUrl = "";
  let mediaType = "";

  if (postId.length > 0) {
    const { data: post } = await supabase
      .from("community_posts")
      .select(
        "id, author_name, body, media_path, media_type",
      )
      .eq("id", postId)
      .maybeSingle();

    if (post != null) {
      const author =
        post.author_name?.toString().trim() ?? "";

      const postBody =
        post.body?.toString().trim() ?? "";

      const mediaPath =
        post.media_path?.toString().trim() ?? "";

      mediaType =
        post.media_type?.toString().trim() ?? "";

      if (author.length > 0) {
        authorName = author;
      }

      if (postBody.length > 0) {
        body = postBody;
      }

      if (mediaPath.length > 0) {
        const { data: signedData } =
          await supabase.storage
            .from("feed-media")
            .createSignedUrl(
              mediaPath,
              60 * 60 * 24,
            );

        mediaUrl =
          signedData?.signedUrl ?? "";
      }
    }
  }

  const title =
    `${authorName} | 999 Wellness`;

  const description =
    body.length > 180
      ? `${body.substring(0, 177)}...`
      : body;

  const safeTitle = escapeHtml(title);
  const safeDescription =
    escapeHtml(description);
  const safeAppUrl = escapeHtml(appUrl);
  const safeMediaUrl =
    escapeHtml(mediaUrl);

  const imageMeta =
    mediaUrl.length > 0 &&
    !mediaType.toLowerCase().contains("video")
      ? `
<meta property="og:image" content="${safeMediaUrl}">
<meta property="og:image:secure_url" content="${safeMediaUrl}">
<meta name="twitter:image" content="${safeMediaUrl}">
`
      : "";

  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">

<title>${safeTitle}</title>

<meta name="description" content="${safeDescription}">

<meta property="og:type" content="article">
<meta property="og:site_name" content="999 Wellness">
<meta property="og:title" content="${safeTitle}">
<meta property="og:description" content="${safeDescription}">
<meta property="og:url" content="${safeAppUrl}">
${imageMeta}

<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${safeTitle}">
<meta name="twitter:description" content="${safeDescription}">

<style>
html, body {
  background: #071329;
  color: white;
  font-family: Arial, sans-serif;
  height: 100%;
  margin: 0;
}

body {
  display: grid;
  place-items: center;
}

.card {
  width: min(90vw, 460px);
  padding: 28px;
  border-radius: 24px;
  background:
    linear-gradient(
      135deg,
      #081c46,
      #12113f,
      #34105e
    );
  border: 1px solid #35e5ff;
  text-align: center;
}

.logo {
  font-size: 28px;
  font-weight: 900;
  color: #49eaff;
}

.sub {
  margin-top: 8px;
  color: #aebada;
}
</style>

<script>
window.setTimeout(function () {
  window.location.replace(
    ${JSON.stringify(appUrl)}
  );
}, 250);
</script>
</head>

<body>
  <div class="card">
    <div class="logo">999 WELLNESS</div>
    <div class="sub">
      Opening shared wellness post...
    </div>
  </div>
</body>
</html>`;

  return new Response(
    html,
    {
      headers: {
        "content-type":
          "text/html; charset=utf-8",
        "cache-control":
          "public, max-age=300",
      },
    },
  );
});
