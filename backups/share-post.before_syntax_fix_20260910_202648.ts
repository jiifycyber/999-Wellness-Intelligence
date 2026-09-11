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

function absoluteUrl(value: string): string {
  const trimmed = value.trim();

  if (trimmed.startsWith("http://") ||
      trimmed.startsWith("https://")) {
    return trimmed;
  }

  return "";
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const postId =
    url.searchParams.get("post")?.trim() ?? "";

  const appUrl = postId.length > 0
    ? `https://wellness.999intelligence.io/?post=${encodeURIComponent(postId)}`
    : "https://wellness.999intelligence.io/";

  let authorName = "999 Wellness";
  let authorId = "";
  let body =
    "Share wellness. Grow the community.";
  let imageUrl = "";
  let mediaType = "";

  if (postId.length > 0) {
    const { data: post } = await supabase
      .from("community_posts")
      .select(
        "id, author_id, author_name, body, media_path, media_type",
      )
      .eq("id", postId)
      .maybeSingle();

    if (post != null) {
      authorId =
        post.author_id?.toString().trim() ?? "";

      finalAuthor:
      {
        const author =
          post.author_name?.toString().trim() ?? "";

        if (author.length > 0) {
          authorName = author;
        }
      }

      const postBody =
        post.body?.toString().trim() ?? "";

      if (postBody.length > 0) {
        body = postBody;
      }

      const mediaPath =
        post.media_path?.toString().trim() ?? "";

      mediaType =
        post.media_type?.toString().trim() ?? "";

      if (mediaPath.length > 0 &&
          !mediaType.toLowerCase().includes("video")) {
        const direct = absoluteUrl(mediaPath);

        if (direct.length > 0) {
          imageUrl = direct;
        } else {
          const { data: signedData } =
            await supabase.storage
              .from("feed-media")
              .createSignedUrl(
                mediaPath,
                60 * 60 * 24,
              );

          imageUrl =
            signedData?.signedUrl ?? "";
        }
      }
    }
  }

  if (imageUrl.length == 0 &&
      authorId.length > 0) {
    const { data: providerProfile } =
      await supabase
        .from("provider_profiles")
        .select("profile_photo_url")
        .eq("id", authorId)
        .maybeSingle();

    const providerPhoto =
      providerProfile?["profile_photo_url"]
        ?.toString()
        .trim() ?? "";

    if (providerPhoto.length > 0) {
      imageUrl = absoluteUrl(providerPhoto);
    }
  }

  if (imageUrl.length == 0 &&
      authorId.length > 0) {
    const { data: profile } =
      await supabase
        .from("profiles")
        .select("profile_photo_url, avatar_url")
        .eq("id", authorId)
        .maybeSingle();

    const profilePhoto =
      profile?["profile_photo_url"]
        ?.toString()
        .trim() ?? "";

    const avatarUrl =
      profile?["avatar_url"]
        ?.toString()
        .trim() ?? "";

    if (profilePhoto.length > 0) {
      imageUrl = absoluteUrl(profilePhoto);
    } else if (avatarUrl.length > 0) {
      imageUrl = absoluteUrl(avatarUrl);
    }
  }

  if (imageUrl.length == 0) {
    imageUrl =
      "https://wellness.999intelligence.io/icons/Icon-512.png";
  }

  const title =
    `${authorName} | 999 Wellness`;

  const description =
    body.length > 180
      ? `${body.substring(0, 177)}...`
      : body;

  const safeTitle =
    escapeHtml(title);

  const safeDescription =
    escapeHtml(description);

  const safeAppUrl =
    escapeHtml(appUrl);

  const safeImageUrl =
    escapeHtml(imageUrl);

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
<meta property="og:image" content="${safeImageUrl}">
<meta property="og:image:secure_url" content="${safeImageUrl}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">

<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${safeTitle}">
<meta name="twitter:description" content="${safeDescription}">
<meta name="twitter:image" content="${safeImageUrl}">

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
