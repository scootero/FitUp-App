export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function jsonResponse(status: number, body: unknown): Response {
  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    },
  );
}

export async function readJsonBody<T>(request: Request): Promise<T> {
  try {
    return await request.json() as T;
  } catch (_error) {
    throw new Error("Invalid JSON body.");
  }
}
