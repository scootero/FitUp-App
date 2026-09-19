import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, jsonResponse, readJsonBody } from "../_shared/http.ts";
import { SUPABASE_URL, supabaseAdmin } from "../_shared/supabase.ts";

type DeleteAccountRequest = {
  operation_id?: string;
  mode?: "prepare" | "delete";
  apple_authorization_code?: string;
};

const anonymousKey = Deno.env.get("SUPABASE_ANON_KEY");

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse(405, { error_code: "method_not_allowed" });

  let operationId: string | undefined;
  let cleanupCompleted = false;
  try {
    const token = bearerToken(request);
    const body = await readJsonBody<DeleteAccountRequest>(request);
    operationId = validUUID(body.operation_id) ? body.operation_id : undefined;
    if (!operationId) return jsonResponse(400, { error_code: "invalid_operation_id" });
    if (!anonymousKey) throw new SanitizedError("server_configuration_missing");

    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !userData.user) return jsonResponse(401, { error_code: "not_authenticated", operation_id: operationId });

    const user = userData.user;
    const { data: profile, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("id")
      .eq("auth_user_id", user.id)
      .maybeSingle();
    if (profileError) throw new SanitizedError("profile_lookup_failed");

    const { data: existingOperation } = await supabaseAdmin
      .from("account_deletion_operations")
      .select("id,auth_user_id,stage,succeeded")
      .eq("id", operationId)
      .maybeSingle();

    if (existingOperation?.auth_user_id && existingOperation.auth_user_id !== user.id) {
      return jsonResponse(403, { error_code: "operation_mismatch", operation_id: operationId });
    }

    if (existingOperation?.succeeded) {
      return jsonResponse(200, { status: "deleted", operation_id: operationId });
    }

    if (!existingOperation) {
      const { error: operationError } = await supabaseAdmin
        .from("account_deletion_operations")
        .insert({
          id: operationId,
          auth_user_id: user.id,
          profile_id: profile?.id ?? null,
          stage: "created",
        });
      if (operationError) throw new SanitizedError("operation_create_failed");
    }

    const requiresAppleAuthorization = isAppleUser(user.app_metadata);
    if (body.mode === "prepare") {
      return jsonResponse(200, {
        status: "prepared",
        operation_id: operationId,
        requires_apple_authorization: requiresAppleAuthorization,
      });
    }

    if (body.mode !== "delete") return jsonResponse(400, { error_code: "invalid_mode", operation_id: operationId });

    if (requiresAppleAuthorization) {
      const code = body.apple_authorization_code?.trim();
      if (!code) {
        return jsonResponse(409, {
          error_code: "apple_authorization_required",
          operation_id: operationId,
        });
      }
      await revokeAppleAuthorization(code);
      await setOperationStage(operationId, "apple_revoked");
    }

    const userClient = createClient(SUPABASE_URL, anonymousKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { error: cleanupError } = await userClient.rpc("perform_account_deletion_cleanup", {
      p_operation_id: operationId,
    });
    if (cleanupError) throw new SanitizedError("cleanup_failed");
    cleanupCompleted = true;

    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user.id);
    if (deleteError) throw new SanitizedError("auth_delete_failed");

    const { error: completionError } = await supabaseAdmin
      .from("account_deletion_operations")
      .update({
        auth_user_id: null,
        profile_id: null,
        stage: "auth_deleted",
        succeeded: true,
        sanitized_error_code: null,
        updated_at: new Date().toISOString(),
        completed_at: new Date().toISOString(),
      })
      .eq("id", operationId);
    if (completionError) throw new SanitizedError("completion_record_failed");

    return jsonResponse(200, { status: "deleted", operation_id: operationId });
  } catch (error) {
    const code = error instanceof SanitizedError ? error.code : "unexpected_failure";
    if (operationId) {
      await supabaseAdmin
        .from("account_deletion_operations")
        .update({
          stage: cleanupCompleted ? "cleanup_complete" : "failed",
          succeeded: false,
          sanitized_error_code: code,
          updated_at: new Date().toISOString(),
        })
        .eq("id", operationId);
    }
    return jsonResponse(500, { error_code: code, operation_id: operationId });
  }
});

class SanitizedError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

function bearerToken(request: Request): string {
  const header = request.headers.get("Authorization") ?? "";
  if (!header.startsWith("Bearer ")) throw new SanitizedError("not_authenticated");
  return header.slice("Bearer ".length).trim();
}

function validUUID(value: string | undefined): value is string {
  return !!value && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function isAppleUser(metadata: Record<string, unknown> | null | undefined): boolean {
  const provider = typeof metadata?.provider === "string" ? metadata.provider : "";
  const providers = Array.isArray(metadata?.providers) ? metadata.providers : [];
  return provider === "apple" || providers.includes("apple");
}

async function setOperationStage(operationId: string, stage: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from("account_deletion_operations")
    .update({ stage, sanitized_error_code: null, updated_at: new Date().toISOString() })
    .eq("id", operationId);
  if (error) throw new SanitizedError("operation_update_failed");
}

async function revokeAppleAuthorization(authorizationCode: string): Promise<void> {
  const clientId = requiredSecret("APPLE_CLIENT_ID");
  const clientSecret = await makeAppleClientSecret(clientId);

  const exchange = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      code: authorizationCode,
      grant_type: "authorization_code",
    }),
  });
  if (!exchange.ok) throw new SanitizedError("apple_code_exchange_failed");

  const tokenPayload = await exchange.json() as { refresh_token?: string; access_token?: string };
  const token = tokenPayload.refresh_token ?? tokenPayload.access_token;
  const hint = tokenPayload.refresh_token ? "refresh_token" : "access_token";
  if (!token) throw new SanitizedError("apple_token_missing");

  const revocation = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      token,
      token_type_hint: hint,
    }),
  });
  if (!revocation.ok) throw new SanitizedError("apple_revocation_failed");
}

async function makeAppleClientSecret(clientId: string): Promise<string> {
  const teamId = requiredSecret("APPLE_TEAM_ID");
  const keyId = requiredSecret("APPLE_KEY_ID");
  const privateKeyPEM = requiredSecret("APPLE_PRIVATE_KEY").replaceAll("\\n", "\n");
  const now = Math.floor(Date.now() / 1000);
  const header = base64URL(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" }));
  const claims = base64URL(JSON.stringify({
    iss: teamId,
    iat: now,
    exp: now + 300,
    aud: "https://appleid.apple.com",
    sub: clientId,
  }));
  const signingInput = `${header}.${claims}`;
  const keyBytes = pemBytes(privateKeyPEM);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64URLBytes(new Uint8Array(signature))}`;
}

function requiredSecret(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new SanitizedError("apple_configuration_missing");
  return value;
}

function pemBytes(pem: string): Uint8Array {
  const raw = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
  const binary = atob(raw);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function base64URL(value: string): string {
  return base64URLBytes(new TextEncoder().encode(value));
}

function base64URLBytes(value: Uint8Array): string {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}
