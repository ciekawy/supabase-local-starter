#!/usr/bin/env bash
# Generate all secrets needed for the local Supabase instance.
# Outputs a ready-to-paste .env block for Dokploy's Environment tab.
set -euo pipefail

# ---- Core secrets ----
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
JWT_SECRET=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9+/' | head -c 48)
SECRET_KEY_BASE=$(openssl rand -base64 64 | tr -dc 'a-zA-Z0-9+/' | head -c 64)
VAULT_ENC_KEY=$(openssl rand -hex 16)
PG_META_CRYPTO_KEY=$(openssl rand -hex 16)
DASHBOARD_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)

# ---- JWT tokens (ANON_KEY and SERVICE_ROLE_KEY) ----
# These are HS256 JWTs signed with JWT_SECRET.
# Payload: { "role": "<role>", "iss": "supabase", "iat": <now>, "exp": <+10 years> }

generate_jwt() {
  local role="$1"
  local secret="$2"
  local iat
  iat=$(date +%s)
  local exp=$((iat + 315360000))  # +10 years

  local header
  header=$(printf '{"alg":"HS256","typ":"JWT"}' | openssl base64 -e | tr -d '=\n' | tr '/+' '_-')

  local payload
  payload=$(printf '{"role":"%s","iss":"supabase","iat":%d,"exp":%d}' "$role" "$iat" "$exp" | openssl base64 -e | tr -d '=\n' | tr '/+' '_-')

  local signature
  signature=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -hmac "$secret" -binary | openssl base64 -e | tr -d '=\n' | tr '/+' '_-')

  printf '%s.%s.%s' "$header" "$payload" "$signature"
}

ANON_KEY=$(generate_jwt "anon" "$JWT_SECRET")
SERVICE_ROLE_KEY=$(generate_jwt "service_role" "$JWT_SECRET")

# ---- Output ----
cat <<EOF
# ============================================
# Supabase Local Secrets — paste into Dokploy
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# ============================================

POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
JWT_SECRET=${JWT_SECRET}
ANON_KEY=${ANON_KEY}
SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=${DASHBOARD_PASSWORD}
SECRET_KEY_BASE=${SECRET_KEY_BASE}
VAULT_ENC_KEY=${VAULT_ENC_KEY}
PG_META_CRYPTO_KEY=${PG_META_CRYPTO_KEY}

# Save ANON_KEY for .env.local (frontend):
# VITE_SUPABASE_PUBLISHABLE_KEY=${ANON_KEY}
EOF
