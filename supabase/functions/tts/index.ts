import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const OPENAI_TTS_URL = "https://api.openai.com/v1/audio/speech";
const BUCKET_NAME = "tts-cache";

// Rate limiting: in-memory store (per edge function instance)
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT_MAX = 100; // requests per window
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour

const ALLOWED_VOICES = new Set(["onyx", "echo", "fable", "nova", "sage"]);
const ALLOWED_FORMATS = new Set(["mp3", "opus", "aac", "flac"]);
const MAX_INPUT_LENGTH = 4500;

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

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    return new Response(
      JSON.stringify({ error: "Server configuration error" }),
      { status: 500, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
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
    const {
      model = "tts-1",
      input,
      voice = "onyx",
      response_format = "mp3",
      speed = 1.0,
    } = body;

    // Validate input text
    if (!input || typeof input !== "string" || input.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: "Missing or invalid 'input' field" }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    if (input.length > MAX_INPUT_LENGTH) {
      return new Response(
        JSON.stringify({ error: `Input too long (max ${MAX_INPUT_LENGTH} characters)` }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    // Validate voice
    if (!ALLOWED_VOICES.has(voice)) {
      return new Response(
        JSON.stringify({ error: `Invalid voice. Allowed: ${[...ALLOWED_VOICES].join(", ")}` }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    // Validate response format
    if (!ALLOWED_FORMATS.has(response_format)) {
      return new Response(
        JSON.stringify({ error: `Invalid format. Allowed: ${[...ALLOWED_FORMATS].join(", ")}` }),
        { status: 400, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
      );
    }

    // Build cache key: voice + SHA-256 hash of input text
    const encoder = new TextEncoder();
    const data = encoder.encode(`${voice}:${input}`);
    const hashBuffer = await crypto.subtle.digest("SHA-256", data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashHex = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
    const cacheKey = `${voice}-${hashHex.slice(0, 32)}.${response_format}`;

    // Initialize Supabase client with service role for storage access
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Check if cached audio exists in storage
    const { data: cachedFile, error: downloadError } = await supabase.storage
      .from(BUCKET_NAME)
      .download(cacheKey);

    if (cachedFile && !downloadError) {
      // Cache hit — return stored audio
      const arrayBuffer = await cachedFile.arrayBuffer();
      return new Response(new Uint8Array(arrayBuffer), {
        status: 200,
        headers: {
          "Content-Type": `audio/${response_format}`,
          "X-Cache": "HIT",
          ...CORS_HEADERS,
        },
      });
    }

    // Cache miss — generate audio via OpenAI TTS
    const openaiResponse = await fetch(OPENAI_TTS_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        input,
        voice,
        response_format,
        speed,
      }),
    });

    if (!openaiResponse.ok) {
      const status = openaiResponse.status;
      // Sanitize error — don't leak OpenAI internals
      return new Response(
        JSON.stringify({ error: `Audio generation failed (${status})` }),
        {
          status: status >= 500 ? 502 : status,
          headers: { "Content-Type": "application/json", ...CORS_HEADERS },
        },
      );
    }

    // Read the audio data
    const audioData = await openaiResponse.arrayBuffer();
    const audioBytes = new Uint8Array(audioData);

    // Save to Supabase Storage (fire-and-forget with error logging)
    supabase.storage
      .from(BUCKET_NAME)
      .upload(cacheKey, audioBytes, {
        contentType: `audio/${response_format}`,
        upsert: true,
      })
      .then(({ error: uploadError }) => {
        if (uploadError) {
          console.error(`[tts-cache] Upload failed for ${cacheKey}:`, uploadError.message);
        }
      })
      .catch((err: unknown) => {
        console.error(`[tts-cache] Upload exception for ${cacheKey}:`, err);
      });

    // Return audio to client
    return new Response(audioBytes, {
      status: 200,
      headers: {
        "Content-Type": `audio/${response_format}`,
        "X-Cache": "MISS",
        ...CORS_HEADERS,
      },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      },
    );
  }
});
