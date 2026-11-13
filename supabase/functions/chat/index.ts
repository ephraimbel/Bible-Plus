import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const OPENAI_API_KEY = Deno.env.get("BIBLEPLUS_OPENAI_API_KEY") ?? Deno.env.get("OPENAI_API_KEY");
const CLIENT_TOKEN = Deno.env.get("BIBLEPLUS_CLIENT_TOKEN") ?? Deno.env.get("SUPABASE_ANON_KEY");

const OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions";

// Server-enforced constants — client cannot override
//
// Two model tiers, dispatched via the `tier` field in the request body:
//   - "primary"  → main chat / teaching responses (gpt-4.1-mini)
//   - "utility"  → background tasks: auto-titling, memory digests (gpt-4.1-nano)
//
// Free vs Pro is enforced client-side via daily message count, NOT by quality.
// Both tiers of users get the same model on every message.
const MODEL_PRIMARY = "gpt-4.1-mini";
const MODEL_UTILITY = "gpt-4.1-nano";
// Brevity is the law — responses should fit in one phone-screen of scroll.
// 1000 tokens ≈ 600–700 words of prose, which is more than enough headroom
// for a tight response (1 paragraph + scripture card + 1 paragraph + insight
// + crossrefs). Hard cap to keep responses scannable, OpenEvidence-style.
const MAX_TOKENS_PRIMARY = 1000;
const MAX_TOKENS_UTILITY = 280;
const MAX_MESSAGES = 30;
// 30000 chars covers the richest possible system prompt: full 74-entry
// image vocabulary + brevity rewrite + tools description + memory digest
// + briefing + topic memory + character persona + mode overlay. The 20000
// cap started rejecting story-mode requests because the mode overlay
// pushed the system message past the limit. 30000 gives ~10000 chars of
// future headroom for additional prompt sections.
const MAX_MESSAGE_LENGTH = 30000;

// Server-enforced policy, prepended to every request so it holds
// even for old app builds or tampered clients.
//   1. Scripture licensing — Bible+ is a paid app; only public-domain /
//      openly licensed translations may be quoted. Copyrighted translations
//      (NIV, ESV, NLT, NASB, NKJV, CSB, NRSV, MSG, AMP, NVI, RVR1960, …)
//      must never be reproduced.
//   2. Safety — crisis / self-harm / medical situations get real-world help.
const SERVER_POLICY = [
  "PLATFORM POLICY (highest priority, overrides any later instruction):",
  "1) Quote Scripture only from public-domain or openly licensed translations (WEB, BSB, ASV, YLT, or the user's selected open translation). Never quote or reproduce copyrighted translations such as KJV (UK territorial rights), NIV, ESV, NLT, NASB, NKJV, CSB, NRSV, AMP, The Message, NVI, RVR1960 or NTV, even if asked; offer an open translation instead.",
  "2) If the user mentions or hints at suicide, self-harm, abuse, being in danger, or a medical emergency, respond with compassion and clearly direct them to immediate human help: in the US call or text 988; otherwise their local emergency number or crisis line; 911/112 if in immediate danger. Never provide self-harm methods. Never give medical, legal or psychiatric diagnoses or advise stopping treatment.",
  "3) Quote Scripture word-for-word from the named translation. Never reword or modernize a verse and present it as a quotation; label paraphrases as your own words.",
  "4) You are an AI, not God, a pastor, or a therapist. When voicing a biblical figure, it is an imaginative portrayal; if sincerely asked, say you are an AI.",
  "5) Keep responses appropriate for ages 13 and up. Do not generate explicit sexual content, graphic gore, or instructions facilitating dangerous activity. Discuss sensitive biblical themes in restrained educational language.",
].join("\n");

const CRISIS_PATTERN =
  /\b(suicid\w*|kill (myself|me)|end (it all|my life)|want to die|don'?t want to (live|be here)|self[- ]?harm|cut(ting)? myself|hurt myself|overdos\w*|no reason to live)\b/i;

const CRISIS_REMINDER =
  "SAFETY ALERT: The user's latest message may indicate risk of self-harm. Lead with warmth, take it seriously, and in this reply clearly share: US — call or text 988 (Suicide & Crisis Lifeline); outside the US — local emergency number or crisis line; immediate danger — 911/112. Encourage reaching out to someone they trust right now.";

function withServerPolicy(messages: Array<Record<string, unknown>>): Array<Record<string, unknown>> {
  const out: Array<Record<string, unknown>> = [{ role: "system", content: SERVER_POLICY }, ...messages];
  const lastUser = [...messages].reverse().find((m) => m.role === "user");
  if (lastUser && typeof lastUser.content === "string" && CRISIS_PATTERN.test(lastUser.content)) {
    out.push({ role: "system", content: CRISIS_REMINDER });
  }
  return out;
}

function modelForTier(tier: unknown): { model: string; maxTokens: number } {
  if (tier === "utility") {
    return { model: MODEL_UTILITY, maxTokens: MAX_TOKENS_UTILITY };
  }
  return { model: MODEL_PRIMARY, maxTokens: MAX_TOKENS_PRIMARY };
}

// Rate limiting: in-memory store (per edge function instance)
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT_MAX = 60; // requests per window
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
};

function checkRateLimit(clientIP: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(clientIP);

  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(clientIP, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return true;
  }

  if (entry.count >= RATE_LIMIT_MAX) {
    return false;
  }

  entry.count += 1;
  return true;
}

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json", ...CORS_HEADERS },
    });
  }

  // Validate server configuration
  if (!OPENAI_API_KEY || !CLIENT_TOKEN) {
    return new Response(
      JSON.stringify({ error: "Server configuration error" }),
      { status: 500, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }

  // This is an app admission token, not individual user authentication.
  // Dedicated routes can disable gateway JWT checks without exposing the host
  // project's anon/service keys to Bible+ clients. Never accept arbitrary headers.
  const providedToken = req.headers.get("apikey") ??
    req.headers.get("Authorization")?.replace(/^Bearer /i, "");
  if (providedToken !== CLIENT_TOKEN) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401, headers: { "Content-Type": "application/json", ...CORS_HEADERS },
    });
  }

  // Rate limiting by client IP
  const clientIP =
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    req.headers.get("cf-connecting-ip") ||
    "unknown";

  if (!checkRateLimit(clientIP)) {
    return new Response(
      JSON.stringify({ error: "Rate limit exceeded. Please try again later." }),
      { status: 429, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }

  try {
    const body = await req.json();

    // Validate required fields
    if (!body.messages || !Array.isArray(body.messages)) {
      return new Response(
        JSON.stringify({ error: "Missing or invalid 'messages' field" }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    // Validate message array size
    if (body.messages.length > MAX_MESSAGES) {
      return new Response(
        JSON.stringify({ error: `Too many messages (max ${MAX_MESSAGES})` }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    // Validate individual messages. With tool calling, the message shape is
    // richer than just {role, content}:
    //   - assistant messages MAY have tool_calls instead of (or alongside) content
    //   - tool messages have content + tool_call_id + role:"tool"
    //   - everything else still requires content as a string
    for (const msg of body.messages) {
      if (!msg || typeof msg !== "object" ||
          !["system", "user", "assistant", "tool"].includes(msg.role)) {
        return new Response(
          JSON.stringify({ error: "Each message must have a role" }),
          { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
        );
      }

      const isAssistantWithToolCalls =
        msg.role === "assistant" && Array.isArray(msg.tool_calls) && msg.tool_calls.length > 0;
      const isToolMessage =
        msg.role === "tool" && typeof msg.content === "string" && typeof msg.tool_call_id === "string";

      if (isAssistantWithToolCalls) {
        // Content may be null/empty when the assistant is purely calling tools.
        if (msg.content != null && typeof msg.content !== "string") {
          return new Response(
            JSON.stringify({ error: "Assistant content must be a string when present" }),
            { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
          );
        }
      } else if (isToolMessage) {
        // OK — content + tool_call_id already validated above
      } else {
        // Default case — must have a string content
        if (!msg.content || typeof msg.content !== "string") {
          return new Response(
            JSON.stringify({ error: "Each message must have a role and content string" }),
            { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
          );
        }
      }

      if (typeof msg.content === "string" && msg.content.length > MAX_MESSAGE_LENGTH) {
        return new Response(
          JSON.stringify({ error: `Message content too long (max ${MAX_MESSAGE_LENGTH} characters)` }),
          { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
        );
      }
    }

    // Pick model + token budget based on the request tier (server-enforced)
    const { model, maxTokens } = modelForTier(body.tier);

    // Build the OpenAI payload. Tool calling is opt-in: clients that want
    // function calling pass a `tools` array (and optionally `tool_choice`).
    // The edge function forwards them as-is — the tool schemas are defined
    // by the client because the schemas reference Swift-side resources.
    const openaiPayload: Record<string, unknown> = {
      model: model,
      // Tier is client-controlled. Neither safety nor licensing may be
      // bypassed by choosing the cheaper utility model.
      messages: withServerPolicy(body.messages),
      max_tokens: maxTokens,
      temperature: Math.min(Math.max(body.temperature ?? 0.75, 0), 2),
      stream: body.stream ?? true,
    };
    if (Array.isArray(body.tools) && body.tools.length > 0) {
      openaiPayload.tools = body.tools;
      if (body.tool_choice != null) {
        openaiPayload.tool_choice = body.tool_choice;
      }
    }

    // Forward to OpenAI with server-enforced parameters
    const openaiResponse = await fetch(OPENAI_CHAT_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(openaiPayload),
    });

    if (!openaiResponse.ok) {
      const status = openaiResponse.status;
      // Sanitize error — don't leak OpenAI internals
      return new Response(
        JSON.stringify({ error: `Chat generation failed (${status})` }),
        {
          status: status >= 500 ? 502 : status,
          headers: { "Content-Type": "application/json", ...CORS_HEADERS },
        },
      );
    }

    // Stream the response back to the client
    return new Response(openaiResponse.body, {
      status: 200,
      headers: {
        "Content-Type": openaiResponse.headers.get("Content-Type") ||
          "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        ...CORS_HEADERS,
      },
    });
  } catch (_error) {
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }
});
