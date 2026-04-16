import { importPKCS8, SignJWT } from "npm:jose@5.9.6";

const teamId = Deno.env.get("APNS_TEAM_ID")?.trim() ?? "";
const keyId = Deno.env.get("APNS_KEY_ID")?.trim() ?? "";
const privateKeyRaw = Deno.env.get("APNS_PRIVATE_KEY") ?? "";
const bundleId = Deno.env.get("APNS_BUNDLE_ID")?.trim() ?? "";
const useSandbox = (Deno.env.get("APNS_USE_SANDBOX") ?? "true").toLowerCase() !== "false";

let cachedJwt: { token: string; expiresAtMs: number } | null = null;

export type ApnsResult = {
  ok: boolean;
  status: number;
  body: string;
};

export type AlertPushInput = {
  deviceToken: string;
  title?: string;
  body: string;
  payload: Record<string, unknown>;
};

export type LiveActivityPushInput = {
  pushToken: string;
  payload: Record<string, unknown>;
};

export function apnsConfigured(): boolean {
  return teamId.length > 0 &&
    keyId.length > 0 &&
    privateKeyRaw.trim().length > 0 &&
    bundleId.length > 0;
}

export async function sendAlertPush(input: AlertPushInput): Promise<ApnsResult> {
  const apsPayload = {
    aps: {
      alert: {
        title: input.title ?? "FitUp",
        body: input.body,
      },
      sound: "default",
      badge: 1,
    },
    ...input.payload,
  };

  return await sendToApns({
    token: input.deviceToken,
    topic: bundleId,
    pushType: "alert",
    payload: apsPayload,
  });
}

export async function sendLiveActivityPush(input: LiveActivityPushInput): Promise<ApnsResult> {
  const apsPayload = {
    aps: {
      timestamp: Math.floor(Date.now() / 1000),
      event: "update",
      "content-state": input.payload,
    },
  };

  return await sendToApns({
    token: input.pushToken,
    topic: `${bundleId}.push-type.liveactivity`,
    pushType: "liveactivity",
    payload: apsPayload,
  });
}

async function sendToApns(args: {
  token: string;
  topic: string;
  pushType: "alert" | "liveactivity";
  payload: Record<string, unknown>;
}): Promise<ApnsResult> {
  if (!apnsConfigured()) {
    return {
      ok: false,
      status: 503,
      body: "APNS credentials are not configured.",
    };
  }

  const jwt = await fetchJwt();
  const host = useSandbox ? "api.sandbox.push.apple.com" : "api.push.apple.com";
  const url = `https://${host}/3/device/${args.token}`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": args.topic,
      "apns-push-type": args.pushType,
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(args.payload),
  });

  return {
    ok: response.ok,
    status: response.status,
    body: await response.text(),
  };
}

async function fetchJwt(): Promise<string> {
  const nowMs = Date.now();
  if (cachedJwt && cachedJwt.expiresAtMs > nowMs + 5 * 60 * 1000) {
    return cachedJwt.token;
  }

  const privateKey = privateKeyRaw.replace(/\\n/g, "\n");
  const key = await importPKCS8(privateKey, "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .setExpirationTime("50m")
    .sign(key);

  cachedJwt = {
    token,
    expiresAtMs: nowMs + 50 * 60 * 1000,
  };
  return token;
}
