import crypto from "node:crypto";

const cache = new Map();

function unauthorized() {
  return {
    isAuthorized: false,
    context: {
      role: "anonymous",
    },
  };
}

function base64UrlDecode(value) {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padding = normalized.length % 4 === 0 ? "" : "=".repeat(4 - (normalized.length % 4));
  return Buffer.from(normalized + padding, "base64").toString("utf8");
}

async function getJwks(uri) {
  const cached = cache.get(uri);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.keys;
  }

  const response = await fetch(uri, {
    headers: {
      "content-type": "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(`JWKS fetch failed with status ${response.status}`);
  }

  const payload = await response.json();
  cache.set(uri, {
    keys: payload.keys ?? [],
    expiresAt: Date.now() + 5 * 60 * 1000,
  });

  return payload.keys ?? [];
}

function verifySignature(token, jwk) {
  const [header, payload, signature] = token.split(".");
  const verifier = crypto.createVerify("RSA-SHA256");
  verifier.update(`${header}.${payload}`);
  verifier.end();

  const publicKey = crypto.createPublicKey({ key: jwk, format: "jwk" });
  return verifier.verify(publicKey, signature.replace(/-/g, "+").replace(/_/g, "/"), "base64");
}

function extractRoles(claims) {
  const claimNames = JSON.parse(process.env.ROLE_CLAIM_NAMES ?? "[]");

  for (const claimName of claimNames) {
    const value = claims[claimName];

    if (Array.isArray(value) && value.length > 0) {
      return value.map(String);
    }

    if (typeof value === "string" && value.length > 0) {
      return value.split(",").map((item) => item.trim()).filter(Boolean);
    }
  }

  return [];
}

function isAllowed({ method, path, roles }) {
  const rules = JSON.parse(process.env.ROUTE_ROLE_RULES ?? "[]");

  if (rules.length === 0) {
    return true;
  }

  const matchingRule = rules.find((rule) => {
    const methodMatch = rule.methods.includes("*") || rule.methods.includes(method);
    const prefixMatch = path.startsWith(rule.route_prefix);
    return methodMatch && prefixMatch;
  });

  if (!matchingRule) {
    return false;
  }

  return matchingRule.roles.some((role) => roles.includes(role));
}

export async function handler(event) {
  try {
    const authHeader = event.headers?.authorization ?? event.headers?.Authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return unauthorized();
    }

    const token = authHeader.slice("Bearer ".length);
    const [encodedHeader, encodedPayload] = token.split(".");
    const header = JSON.parse(base64UrlDecode(encodedHeader));
    const claims = JSON.parse(base64UrlDecode(encodedPayload));

    const now = Math.floor(Date.now() / 1000);
    const audience = JSON.parse(process.env.JWT_AUDIENCE ?? "[]");
    const issuer = process.env.JWT_ISSUER;

    if (claims.exp && claims.exp < now) {
      return unauthorized();
    }

    if (claims.nbf && claims.nbf > now) {
      return unauthorized();
    }

    if (issuer && claims.iss !== issuer) {
      return unauthorized();
    }

    const aud = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
    if (audience.length > 0 && !audience.some((item) => aud.includes(item))) {
      return unauthorized();
    }

    const jwks = await getJwks(process.env.JWKS_URI);
    const jwk = jwks.find((key) => key.kid === header.kid);
    if (!jwk || !verifySignature(token, jwk)) {
      return unauthorized();
    }

    const roles = extractRoles(claims);
    const method = event.requestContext?.http?.method ?? "GET";
    const path = event.rawPath ?? "/";

    if (!isAllowed({ method, path, roles })) {
      return unauthorized();
    }

    const principalClaim = process.env.PRINCIPAL_ID_CLAIM ?? "sub";
    const principalId = claims[principalClaim] ?? "unknown";

    return {
      isAuthorized: true,
      context: {
        principalId: String(principalId),
        role: roles.join(","),
      },
    };
  } catch (error) {
    console.error("Authorization failure", error);
    return unauthorized();
  }
}
