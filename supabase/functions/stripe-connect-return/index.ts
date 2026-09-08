Deno.serve((_req) => {
  const html = [
    "<!DOCTYPE html>",
    "<html lang=\"en\">",
    "<head>",
    "<meta charset=\"UTF-8\">",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">",
    "<title>999 Wellness Intelligence</title>",
    "<style>",
    "html,body{margin:0;padding:0;min-height:100%;background:#050712;color:#fff;font-family:Arial,Helvetica,sans-serif;}",
    "body{min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;box-sizing:border-box;}",
    ".card{width:100%;max-width:620px;padding:48px 32px;box-sizing:border-box;border-radius:28px;text-align:center;background:linear-gradient(135deg,#17112d,#0b1020);border:1px solid #6845b8;box-shadow:0 0 60px rgba(126,87,255,.22);}",
    ".brand{color:#b99cff;font-size:14px;font-weight:800;letter-spacing:2px;margin-bottom:24px;}",
    "h1{font-size:34px;margin:0 0 16px;}",
    "p{color:#cbc7d8;font-size:16px;line-height:1.6;margin:0;}",
    ".status{display:inline-block;margin-top:26px;padding:11px 19px;border-radius:999px;background:#123a29;color:#7ef0b0;font-weight:800;}",
    "</style>",
    "</head>",
    "<body>",
    "<div class=\"card\">",
    "<div class=\"brand\">999 WELLNESS INTELLIGENCE</div>",
    "<h1>Payout setup complete</h1>",
    "<p>Your payout setup has been submitted successfully. You may now close this page and return to your 999 Wellness provider dashboard.</p>",
    "<div class=\"status\">PAYOUT SETUP SUBMITTED</div>",
    "</div>",
    "</body>",
    "</html>"
  ].join("");

  return new Response(html, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=UTF-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff"
    }
  });
});
