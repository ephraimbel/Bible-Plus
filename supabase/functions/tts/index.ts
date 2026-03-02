import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const OPENAI_TTS_URL = "https://api.openai.com/v1/audio/speech";
const BUCKET_NAME = "tts-cache";

Deno.serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!OPENAI_API_KEY) {
    return new Response(
      JSON.stringify({ error: "OpenAI API key not configured" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
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

    if (!input || typeof input !== "string") {
      return new Response(
        JSON.stringify({ error: "Missing or invalid 'input' field" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
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
    const supabase = createClient(
      SUPABASE_URL!,
      SUPABASE_SERVICE_ROLE_KEY!,
    );

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
          "Access-Control-Allow-Origin": "*",
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
      const errorText = await openaiResponse.text();
      return new Response(errorText, {
        status: openaiResponse.status,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      });
    }

    // Read the audio data
    const audioData = await openaiResponse.arrayBuffer();
    const audioBytes = new Uint8Array(audioData);

    // Save to Supabase Storage (fire-and-forget — don't block response)
    supabase.storage
      .from(BUCKET_NAME)
      .upload(cacheKey, audioBytes, {
        contentType: `audio/${response_format}`,
        upsert: true,
      })
      .then(({ error: uploadError }) => {
        if (uploadError) {
          console.error("Cache upload failed:", uploadError.message);
        }
      });

    // Return audio to client
    return new Response(audioBytes, {
      status: 200,
      headers: {
        "Content-Type": `audio/${response_format}`,
        "X-Cache": "MISS",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(error) }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      },
    );
  }
});
