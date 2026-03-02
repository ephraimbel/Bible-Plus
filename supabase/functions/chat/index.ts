import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions";

// Server-enforced constants — client cannot override
const MODEL = "gpt-4.1-nano";
const MAX_TOKENS = 600;
const MAX_MESSAGES = 30;
const MAX_MESSAGE_LENGTH = 5000;

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
  if (!OPENAI_API_KEY) {
    return new Response(
      JSON.stringify({ error: "Server configuration error" }),
      { status: 500, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }

  // Verify Supabase JWT from Authorization header
  if (SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY) {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({ error: "Missing authorization" }),
        { status: 401, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    const token = authHeader.replace("Bearer ", "");
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    // For anon key access (no user session), verify the token matches the anon key
    // by checking that it's a valid JWT or the anon key itself
    if (authError && token !== Deno.env.get("SUPABASE_ANON_KEY")) {
      return new Response(
        JSON.stringify({ error: "Invalid authorization" }),
        { status: 401, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }
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

    // Validate individual message content length
    for (const msg of body.messages) {
      if (!msg.role || !msg.content || typeof msg.content !== "string") {
        return new Response(
          JSON.stringify({ error: "Each message must have a role and content string" }),
          { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
        );
      }
      if (msg.content.length > MAX_MESSAGE_LENGTH) {
        return new Response(
          JSON.stringify({ error: `Message content too long (max ${MAX_MESSAGE_LENGTH} characters)` }),
          { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
        );
      }
    }

    // Forward to OpenAI with server-enforced parameters
    const openaiResponse = await fetch(OPENAI_CHAT_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: MODEL,
        messages: body.messages,
        max_tokens: MAX_TOKENS,
        temperature: Math.min(Math.max(body.temperature ?? 0.75, 0), 2),
        stream: body.stream ?? true,
      }),
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
