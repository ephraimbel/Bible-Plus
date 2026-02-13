import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const OPENAI_TTS_URL = "https://api.openai.com/v1/audio/speech";

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

    // Validate required fields
    if (!body.input || typeof body.input !== "string") {
      return new Response(
        JSON.stringify({ error: "Missing or invalid 'input' field" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // Forward to OpenAI with server-side API key
    const openaiResponse = await fetch(OPENAI_TTS_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: body.model || "tts-1",
        input: body.input,
        voice: body.voice || "onyx",
        response_format: body.response_format || "mp3",
        speed: body.speed ?? 1.0,
      }),
    });

    if (!openaiResponse.ok) {
      const errorText = await openaiResponse.text();
      return new Response(errorText, {
        status: openaiResponse.status,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Buffer the audio data and return it
    const audioData = await openaiResponse.arrayBuffer();
    return new Response(audioData, {
      status: 200,
      headers: {
        "Content-Type": "audio/mpeg",
        "Content-Length": String(audioData.byteLength),
      },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Internal server error", details: String(error) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
