# Keycloak Integration Guide

Complete guide to integrate Evo CRM with SSO authentication via Keycloak using OAuth 2.0 + PKCE.

## Integration Architecture

```
┌─────────────────┐     PKCE Auth URL      ┌─────────────────┐
│                 │ ─────────────────────► │                 │
│  Evo Frontend   │                        │  Keycloak       │
│  (React/Vite)   │ ◄───────────────────── │  Server         │
│                 │   Redirect with code   │  (Port 8081)    │
└────────┬────────┘                        └─────────────────┘
         │
         │ POST /auth/keycloak_exchange
         │ {code, code_verifier, redirect_uri}
         ▼
┌─────────────────────────────────────────────────────────────┐
│                     Evo Auth Service                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │ CodeExchanger│  │ JwtValidator │  │ UserProvisioner      │ │
│  │              │  │              │  │                      │ │
│  │ Exchanges    │  │ Validates JWT│  │ • Creates/updates user│ │
│  │ code for     │  │ against JWKS │  │ • Sync roles (JIT)   │ │
│  │ tokens       │  │              │  │ • Assigns permissions│ │
│  └──────────────┘  └──────────────┘  └──────────────────────┘ │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Role Sync: Reads KEYCLOAK_ROLES_CLAIM (default:         │ │
│  │ realm_access.roles) and syncs with local roles table    │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
         │
         │ Bearer Token + User
         ▼
┌─────────────────┐
│  Evo Frontend   │ ◄── User authenticated with synced roles
│  (Dashboard)    │
└─────────────────┘
```

### Authentication Flow (PKCE)

1. **Frontend** generates `code_verifier` + `code_challenge` (S256)
2. **Frontend** redirects to Keycloak with the challenge
3. **User** authenticates in Keycloak
4. **Keycloak** redirects to the callback with `authorization_code`
5. **Frontend** sends the code to the backend (`evo-auth`)
6. **Backend** exchanges code for tokens (server-side, never exposes secrets to the browser)
7. **Backend** validates JWT, provisions user, and syncs roles
8. **Backend** returns its own Bearer token to the frontend
9. **Frontend** uses the Bearer token for subsequent API calls

### Detailed Flow (Full Architecture)

```
┌─────────────┐                                    ┌─────────────┐
│   Frontend  │                                    │  Keycloak   │
└──────┬──────┘                                    └──────┬──────┘
       │                                                  │
       │ 1. User clicks "Login with Keycloak"             │
       │                                                  │
       │ 2. Frontend generates PKCE code_verifier         │
       │    and redirects to Keycloak authorize endpoint    │
       │───────────────────────────────────────────────────>│
       │                                                  │
       │ 3. User authenticates in Keycloak                  │
       │    Keycloak redirects back with authorization code │
       │<───────────────────────────────────────────────────│
       │                                                  │
       │ 4. Frontend sends code + code_verifier           │
       │    to backend /api/v1/auth/keycloak_exchange     │
       │───────────────────────────────────────────────────>│
       │                                ┌───────────────────┐
       │                                │   Evo Auth        │
       │                                │   Service         │
       │                                └─────────┬─────────┘
       │                                          │
       │                                          │ 5. Exchange code
       │                                          │    for tokens with
       │                                          │    Keycloak token endpoint
       │                                          │─────────────────────>│
       │                                          │                      │
       │                                          │ 6. Keycloak returns
       │                                          │    access_token + id_token
       │                                          │<─────────────────────│
       │                                          │
       │                                          │ 7. Validate JWT against
       │                                          │    JWKS endpoint
       │                                          │─────────────────────>│
       │                                          │<─────────────────────│
       │                                          │
       │                                          │ 8. Provision/Update user
       │                                          │    Sync roles from claims
       │                                          │
       │ 9. Return Evo OAuth tokens               │
       │<─────────────────────────────────────────│
       │                                          │
```

## Requirements

- Docker and Docker Compose installed
- `.env` file configured with Keycloak variables
- Keycloak server accessible (included in docker-compose)

## .env Configuration

Make sure these variables are in your `.env`:

### Backend Variables (evo-auth-service)

```env
# ─────────────────────────────────────────────────────────────────
# KEYCLOAK - Backend Configuration
# ─────────────────────────────────────────────────────────────────
# Enable/disable the Keycloak integration
KEYCLOAK_ENABLED=true

# Public URL of the Keycloak realm (seen by the browser)
KEYCLOAK_ISSUER=http://localhost:8081/realms/organization

# Client ID registered in Keycloak
KEYCLOAK_CLIENT_ID=organization-crm-frontend

# Internal URL for service-to-service communication (Docker network)
# Falls back to KEYCLOAK_ISSUER if not set
KEYCLOAK_INTERNAL_URL=http://keycloak:8080/realms/organization

# Disable SSL verification in development (self-signed certs)
KEYCLOAK_SSL_VERIFY=false

# JWT claim where roles are read from (dot notation supported)
# Default: realm_access.roles
# Alternatives: permissions, realm_access.roles, resource_access.{client_id}.roles
KEYCLOAK_ROLES_CLAIM=realm_access.roles
```

### Frontend Variables (evo-ai-frontend)

```env
# ─────────────────────────────────────────────────────────────────
# KEYCLOAK - Frontend Configuration (VITE_* are build-time)
# ─────────────────────────────────────────────────────────────────
VITE_KEYCLOAK_ENABLED=true
VITE_KEYCLOAK_ISSUER=http://localhost:8081/realms/organization
VITE_KEYCLOAK_CLIENT_ID=organization-crm-frontend
VITE_KEYCLOAK_REDIRECT_URI=http://localhost:5173/auth/callback
```

## Start the Stack with Keycloak

### Option 1: All-in-one (recommended for development)

```bash
docker compose -f docker-compose.yml -f docker-compose.keycloak-integration.yml up --build -d
```

This command starts:
- All application services (CRM, Auth, Core, Processor, Frontend)
- Keycloak server (port 8081)
- MySQL for Keycloak (port 3366)
- Network integration between `evo-auth` and Keycloak

### Option 2: Piece by piece (if you need more control)

```bash
# 1. Keycloak and its database only
docker compose -f docker-compose.keycloak-integration.yml up -d keycloak db-keycloak

# 2. Wait for Keycloak to be ready (healthy)
docker compose -f docker-compose.keycloak-integration.yml ps

# 3. Start the rest of the application
docker compose up -d
```

## Configure Keycloak

### 1. Access the Admin Console

- **URL**: http://localhost:8081/admin
- **Username**: `admin`
- **Password**: `admin`

### 2. Create a Realm

1. In the top-left dropdown, click **Create realm**
2. **Realm name**: `organization` (or the appropriate name)
3. Click **Create**

### 3. Create the Client

1. Go to **Clients** → **Create client**
2. Configure:
   - **Client ID**: `organization-crm-frontend` (must match `KEYCLOAK_CLIENT_ID`)
   - **Client authentication**: OFF (public client for PKCE)
   - **Authentication flow**: Standard flow ✓
   - **Valid redirect URIs**: `http://localhost:5173/*`
   - **Web origins**: `http://localhost:5173`
3. In **Advanced** → **Authentication flow overrides**:
   - **Proof Key for Code Exchange Code Challenge Method**: `S256`

### 4. Configure Roles (Optional)

Roles in Keycloak are automatically synchronized with the local role system. To create custom roles:

1. In Keycloak, go to **Realm roles** → **Create role**
2. Create roles such as: `supervisor`, `admin`, `manager`, etc.
3. Assign roles to users in **Users** → {user} → **Role mapping**

### 5. Create Test Users

1. Go to **Users** → **Add user**
2. Fill in basic data
3. In **Credentials** → **Set password** (temporary or permanent)
4. In **Role mapping**, assign realm roles

## Keycloak Client Configuration (Detailed)

### Required Settings

1. **Client Protocol**: `openid-connect`
2. **Client Authentication**: OFF (public client for PKCE)
3. **Authorization**: OFF
4. **Standard Flow**: ON (Standard Flow Enabled)
5. **Direct Access Grants**: OFF (PKCE only)
6. **Implicit Flow**: OFF

### Valid Redirect URIs

Add the frontend callback URLs:
- `http://localhost:5173/*` (development)
- `https://app.example.com/*` (production)
- `http://localhost:5173/auth/callback` (specific callback)

### Web Origins

Configure CORS origins:
- `http://localhost:5173`
- `https://app.example.com`
- Or use `+` to allow all subdomains

### Advanced Settings

Go to **Advanced** → **Authentication flow overrides**:
- **Proof Key for Code Exchange Code Challenge Method**: `S256`

### Mappers (Optional - to include roles in the token)

To include realm roles in the JWT:
1. Go to **Client Scopes** → **roles** → **Mappers**
2. Click **Add mapper** → **By configuration**
3. Select **realm roles**
4. Configure:
   - **Token Claim Name**: `realm_access.roles`
   - **Add to ID token**: ON
   - **Add to access token**: ON
   - **Add to userinfo**: ON

## Database Schema

The auth service uses the following columns to track the Keycloak integration:

```ruby
# db/migrate/xxx_add_keycloak_sub_to_users.rb
class AddKeycloakSubToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :keycloak_sub, :string
    add_index :users, :keycloak_sub, unique: true
  end
end

# db/migrate/xxx_add_keycloak_id_token_to_users.rb
class AddKeycloakIdTokenToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :keycloak_id_token, :text
  end
end
```

**Fields:**
- `keycloak_sub` - Unique Keycloak identifier (subject) per realm
- `keycloak_id_token` - Cached ID token for logout

**Recommended indexes:**
```ruby
add_index :users, :keycloak_sub, unique: true
add_index :users, [:email, :provider]  # For JIT lookup
```

## Role Synchronization

### Script to Create Roles from Keycloak

The auth service includes a rake task to import roles from Keycloak and assign permissions:

```bash
# Create roles imported from Keycloak (with 'agent' permissions)
docker compose exec evo-auth bundle exec rails keycloak:create_roles ROLES='supervisor,admin,manager'

# Create roles of type 'account' (instead of 'user')
docker compose exec evo-auth bundle exec rails keycloak:create_roles ROLES='org_admin,org_owner' ROLE_TYPE='account'
```

This script:
- Creates the roles in the local table if they do not exist
- Assigns the `agent` role permissions as base permissions
- Keeps existing roles (does not duplicate)

### How JIT Synchronization Works

When a user authenticates:

1. **JwtValidator** verifies the JWT against Keycloak's JWKS
2. **UserProvisioner** extracts roles from the configured claim (`KEYCLOAK_ROLES_CLAIM`)
3. Looks up local roles that match by `key`
4. Assigns new roles, revokes those no longer present
5. If the user has no roles in Keycloak, assigns `agent` by default

```ruby
# The roles claim can be configured as:
# realm_access.roles → claims["realm_access"]["roles"]
# permissions → claims["permissions"]
# resource_access.{client_id}.roles → claims["resource_access"]["organization-crm-frontend"]["roles"]
```

## System Components

### Backend (evo-auth-service)

| Component | Location | Description |
|-----------|----------|-------------|
| `Keycloak::CodeExchanger` | `lib/keycloak/code_exchanger.rb` | Exchanges authorization code for tokens (server-side) |
| `Keycloak::JwtValidator` | `lib/keycloak/jwt_validator.rb` | Validates JWT against JWKS with cache (TTL: 5min) |
| `Keycloak::UserProvisioner` | `lib/keycloak/user_provisioner.rb` | JIT provisioning and role sync |
| `Keycloak::LogoutUrl` | `lib/keycloak/logout_url.rb` | Builds logout URL with id_token_hint |
| Rake task | `lib/tasks/keycloak_roles.rake` | Creates roles from CLI |
| AuthController | `app/controllers/api/v1/auth_controller.rb` | `POST /auth/keycloak_exchange` endpoint |

### Frontend (evo-ai-frontend)

| Component | Location | Description |
|-----------|----------|-------------|
| `keycloakService.ts` | `src/services/auth/keycloakService.ts` | PKCE: generates challenge, builds auth URL, exchanges code |
| `KeycloakCallback.tsx` | `src/pages/Auth/KeycloakCallback.tsx` | Page that receives the Keycloak callback |
| `AuthContext.tsx` | `src/contexts/AuthContext.tsx` | Detects whether Keycloak is enabled |

## Frontend Implementation

### PKCE - Generating Parameters

```typescript
// Generate code_verifier (43-128 characters)
function generateCodeVerifier(): string {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return base64URLEncode(array);
}

// Generate code_challenge from verifier
async function generateCodeChallenge(verifier: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  return base64URLEncode(digest);
}

// Helper: Base64URL encoding
function base64URLEncode(buffer: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buffer)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}
```

### Login Flow

```typescript
const CODE_VERIFIER_KEY = '_kc_cv';

function _getKeycloakEnv() {
  return {
    enabled:  (import.meta.env.VITE_KEYCLOAK_ENABLED  as string | undefined) ?? '',
    issuer:   (import.meta.env.VITE_KEYCLOAK_ISSUER   as string | undefined) ?? '',
    clientId: (import.meta.env.VITE_KEYCLOAK_CLIENT_ID as string | undefined) ?? '',
  };
}

export function isKeycloakEnabled(): boolean {
  const { enabled, issuer, clientId } = _getKeycloakEnv();
  if (enabled.startsWith('VITE_') || enabled !== 'true') return false;
  const issuerSet  = !!issuer   && !issuer.startsWith('VITE_');
  const clientSet  = !!clientId && !clientId.startsWith('VITE_');
  return issuerSet && clientSet;
}

export async function buildKeycloakAuthUrl(redirectUri: string): Promise<string> {
  const { issuer, clientId } = _getKeycloakEnv();
  if (!issuer || !clientId) {
    throw new Error('Keycloak is not configured (VITE_KEYCLOAK_ISSUER / VITE_KEYCLOAK_CLIENT_ID)');
  }

  const codeVerifier = generateCodeVerifier();
  const challenge = await generateCodeChallenge(codeVerifier);

  sessionStorage.setItem(CODE_VERIFIER_KEY, codeVerifier);

  const params = new URLSearchParams({
    client_id:             clientId,
    redirect_uri:          redirectUri,
    response_type:         'code',
    scope:                 'openid email profile',
    code_challenge:        challenge,
    code_challenge_method: 'S256',
  });

  return `${issuer}/protocol/openid-connect/auth?${params}`;
}
```

### Callback Handling

```typescript
// /auth/callback route handler
export async function exchangeKeycloakCode(
  code: string,
  redirectUri: string,
): Promise<{ user: UserResponse }> {
  const codeVerifier = sessionStorage.getItem(CODE_VERIFIER_KEY);
  if (!codeVerifier) throw new Error('Missing PKCE code verifier — session may have expired');

  try {
    const response = await apiAuth.post('/auth/keycloak_exchange', {
      code,
      code_verifier: codeVerifier,
      redirect_uri:  redirectUri,
    });

    // Only remove code_verifier after successful exchange
    sessionStorage.removeItem(CODE_VERIFIER_KEY);

    const data = extractData<{ user: UserResponse; token: { access_token: string } }>(response);
    const accessToken = data?.token?.access_token || (response.data as any)?.access_token;

    if (accessToken) {
      useAuthStore.getState().setAccessToken(accessToken);
    }

    return { user: data.user };
  } catch (error) {
    // Don't remove code_verifier on error - allows retry if needed
    throw error;
  }
}
```

### Logout

```typescript
async function logout() {
  const response = await fetch('/api/v1/auth/logout', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${localStorage.getItem('access_token')}`
    }
  });
  
  const data = await response.json();
  
  // Clear local tokens
  localStorage.removeItem('access_token');
  localStorage.removeItem('refresh_token');
  
  // If Keycloak logout URL is provided, redirect to it
  if (data.data.keycloak_logout_url) {
    window.location.href = data.data.keycloak_logout_url;
  } else {
    window.location.href = '/login';
  }
}
```

### Vue/React Component Example

```vue
<template>
  <button @click="loginWithKeycloak" :disabled="loading">
    {{ loading ? 'Redirecting...' : 'Login with Keycloak' }}
  </button>
</template>

<script setup>
import { ref } from 'vue';

const loading = ref(false);

async function loginWithKeycloak() {
  if (!isKeycloakEnabled()) {
    console.error('Keycloak is not enabled');
    return;
  }
  
  loading.value = true;
  
  try {
    const authUrl = await buildKeycloakAuthUrl(
      `${window.location.origin}/auth/callback`
    );
    window.location.href = authUrl;
  } catch (error) {
    console.error('Login initiation failed:', error);
    loading.value = false;
  }
}
</script>
```

## API Endpoints

### POST /api/v1/auth/keycloak_exchange

Exchanges a Keycloak authorization code for an own Bearer token.

**Request:**
```json
{
  "code": "keycloak_authorization_code",
  "code_verifier": "pkce_verifier_generated_by_frontend",
  "redirect_uri": "http://localhost:5173/auth/callback"
}
```

**Response (200):**
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe",
    "role": "supervisor"
  },
  "access_token": "own_jwt_token",
  "token_type": "Bearer",
  "expires_in": 7200
}
```

**Errors:**
- `KEYCLOAK_NOT_CONFIGURED` (501): Keycloak is not enabled
- `TOKEN_EXCHANGE_FAILED` (502): Error exchanging with Keycloak
- `INVALID_TOKEN` (401): Invalid JWT or signature not verified
- `MISSING_TOKEN` (400): Missing code or keycloak_token

## Backend Implementation

### CodeExchanger - PKCE Server-side Exchange

```ruby
# Exchanges authorization code for tokens (never exposes secrets to the browser)
tokens = Keycloak::CodeExchanger.exchange(
  code: params[:code],
  code_verifier: params[:code_verifier],
  redirect_uri: params[:redirect_uri]
)
# Returns: { access_token: "...", id_token: "..." }
```

### JwtValidator - JWT Validation against JWKS

```ruby
# Validates JWT against Keycloak's JWKS endpoint with cache (TTL: 300s)
claims = Keycloak::JwtValidator.verify(raw_token)
# Returns: claims hash or raise Keycloak::JwtValidator::Error

# Features:
# - JWKS caching (300 seconds TTL)
# - Thread-safe cache with mutex
# - Supports multiple issuers (public + internal)
# - RSA verification (RS256, RS384, RS512)
```

### UserProvisioner - JIT Provisioning and Role Sync

```ruby
# Creates/updates user and synchronizes roles from Keycloak
user = Keycloak::UserProvisioner.provision!(claims)

# Features:
# - Lookup by keycloak_sub (preferred) or email
# - Creates new users with provider="keycloak"
# - Syncs roles from JWT claims (realm + client roles)
# - Full synchronization (Keycloak is source of truth)

# Role Extraction:
# - Realm roles: from KEYCLOAK_ROLES_CLAIM (default: realm_access.roles)
# - Client roles: from resource_access.{client_id}.roles
```

### LogoutUrl - Logout URL Construction

```ruby
# Builds Keycloak logout URL to terminate the session
url = Keycloak::LogoutUrl.build(
  id_token_hint: user.keycloak_id_token,
  post_logout_redirect_uri: "#{frontend_url}/login"
)
# The frontend must redirect to this URL to end the Keycloak session
```

### Endpoint in AuthController

```ruby
# POST /api/v1/auth/keycloak_exchange
def keycloak_exchange
  unless ENV['KEYCLOAK_ENABLED'] == 'true'
    return error_response('KEYCLOAK_NOT_CONFIGURED', ...)
  end

  kc_tokens = Keycloak::CodeExchanger.exchange(
    code: params[:code],
    code_verifier: params[:code_verifier],
    redirect_uri: params[:redirect_uri]
  )
  
  claims = Keycloak::JwtValidator.verify(kc_tokens[:access_token])
  user   = Keycloak::UserProvisioner.provision!(claims)
  user.update_columns(keycloak_id_token: kc_tokens[:id_token])
  
  render_successful_login(user)
end
```

## Verify the Integration

1. Open the frontend: http://localhost:5173
2. Click "Login with Keycloak"
3. It should redirect to Keycloak (localhost:8081)
4. Enter Keycloak user credentials
5. Return to the dashboard with successful login
6. Verify that roles were synchronized correctly

## Production-like Test (TLS Simulation)

Development uses `docker-compose.keycloak-integration.yml` (HTTP, `start-dev`,
`KEYCLOAK_SSL_VERIFY=false`). To validate the integration the way it will behave
in production — HTTPS, valid certificate chain, and exact `iss` matching — use
the prod-test stack (real Docker Hub images + nginx gateway + `RAILS_ENV=production`)
extended with `docker-compose.keycloak-prod-test.yaml`.

### What this simulation reproduces

| Aspect | Development | Production-like Test |
|--------|-------------|----------------------|
| Keycloak mode | `start-dev` | `start` (production mode) |
| Transport | HTTP (`8081`) | HTTPS native TLS (`8443`) |
| `KEYCLOAK_SSL_VERIFY` | `false` | `true` (CA-validated chain) |
| Issuer (`iss`) | `http://localhost:8081/...` | `https://keycloak.localhost:8443/...` |
| Backend → Keycloak | `http://keycloak:8080` | `https://keycloak.localhost:8443` (same host as browser) |
| Frontend `VITE_*` | build args | runtime injection (`docker-entrypoint.sh`) |
| App services | dev images | published `:latest` images via gateway |

The key trick: the browser **and** the auth backend reach Keycloak through the
**same hostname** (`keycloak.localhost:8443`) via a Docker network alias, so the
token's `iss` claim matches `KEYCLOAK_ISSUER` exactly. The backend trusts the
self-signed CA through `SSL_CERT_FILE`, which Ruby/OpenSSL honours for the
default trust store — so `KEYCLOAK_SSL_VERIFY=true` genuinely validates the chain.

### Steps

```bash
# 1. Generate the local CA + server certificate for keycloak.localhost
./keycloak-certs/generate-certs.sh

# 2. (Fallback) ensure keycloak.localhost resolves to loopback.
#    Most browsers resolve *.localhost automatically; curl needs /etc/hosts:
echo "127.0.0.1 keycloak.localhost" | sudo tee -a /etc/hosts

# 3. Bring up the production-like stack with TLS Keycloak
BACKEND_URL=http://host.docker.internal:3030 \
FRONTEND_URL=http://host.docker.internal:5173 \
  docker compose \
    -f docker-compose.prod-test.yaml \
    -f docker-compose.keycloak-prod-test.yaml up -d

# 4. Configure the realm + PKCE client in the admin console
#    https://keycloak.localhost:8443/admin  (admin / admin)
#    - Realm: organization
#    - Client: organization-crm-frontend (public, Standard Flow, PKCE S256)
#    - Valid redirect URIs: http://localhost:5173/*
#    - Web origins: http://localhost:5173

# 5. Test the login at http://localhost:5173
```

> The admin console and Keycloak login screen will show a browser warning for
> the self-signed certificate. Accept it (or import `keycloak-certs/keycloak-ca.crt`
> into your OS/browser trust store) so the redirect completes cleanly.

### Verifying iss matching and TLS from the backend

```bash
# JWKS fetch over TLS from inside the auth container (must succeed, no cert error).
# curl uses its own CA bundle, so pass the CA explicitly (Ruby uses SSL_CERT_FILE).
docker compose -f docker-compose.prod-test.yaml -f docker-compose.keycloak-prod-test.yaml \
  exec evo_auth curl --cacert /certs/keycloak-ca.crt -v \
  https://keycloak.localhost:8443/realms/organization/protocol/openid-connect/certs

# Watch the role sync / iss validation logs during login
docker compose -f docker-compose.prod-test.yaml -f docker-compose.keycloak-prod-test.yaml \
  logs -f evo_auth | grep -E "Keycloak|issuer"
```

If you see `Invalid issuer '...'`, the token `iss` does not match
`KEYCLOAK_ISSUER`/`KEYCLOAK_INTERNAL_URL` — check that `KC_HOSTNAME` and both URLs
use the identical scheme, host, and port (`https://keycloak.localhost:8443`).

### Tear down

```bash
docker compose -f docker-compose.prod-test.yaml -f docker-compose.keycloak-prod-test.yaml down -v
```

## Troubleshooting

### Error 502 on Login

Verify that:
- `evo-auth` can reach Keycloak:
  ```bash
  docker compose exec evo-auth curl http://keycloak:8080/health/ready
  ```
- The variables `KEYCLOAK_INTERNAL_URL` and `KEYCLOAK_SSL_VERIFY` are correct in `.env`
- The realm and client are configured in Keycloak
- The realm exists and the client is in the correct realm

### Frontend Does Not Show the Keycloak Option

- Verify that `VITE_KEYCLOAK_ENABLED=true` in `.env`
- Verify that `VITE_KEYCLOAK_ISSUER` and `VITE_KEYCLOAK_CLIENT_ID` are set
- Rebuild the frontend image:
  ```bash
  docker compose build evo-frontend
  ```
- Check the browser console for configuration errors

### Keycloak Does Not Respond

```bash
# View Keycloak logs
docker compose -f docker-compose.keycloak-integration.yml logs keycloak

# Verify the DB is ready
docker compose -f docker-compose.keycloak-integration.yml logs db-keycloak

# Verify healthcheck
curl http://localhost:8081/health/ready
```

### "Invalid issuer" Error

Keycloak's JWT has an `iss` claim that must match `KEYCLOAK_ISSUER` or `KEYCLOAK_INTERNAL_URL`. Verify:
- If the token has `iss: https://...` but the config is `http://...`, adjust the URLs
- For Docker development, both URLs (public and internal) are accepted

### Roles Not Synchronized

- Verify `KEYCLOAK_ROLES_CLAIM` points to the correct claim in the JWT
- Inspect the JWT at https://jwt.io to see the available claims
- Verify that the roles exist in the local table (`roles` table)
- Use the rake task to create missing roles
- Review `evo-auth` logs for synchronization messages

### PKCE: "Missing code_verifier"

- The `code_verifier` is stored in `sessionStorage` and must persist across the redirect
- Verify that the callback domain is the same as the one that started the flow
- Do not reload the page between login initiation and the callback

### PKCE Verification Failed

- Ensure `code_challenge_method` is exactly `S256` (case-sensitive)
- Verify that the `code_verifier` matches the generated challenge
- Confirm that `code_verifier` is URL-safe base64 encoded
- The verifier must be 43-128 characters long

### JWKS Fetch Failures (Backend)

Verify that `KEYCLOAK_INTERNAL_URL` is accessible from the backend:

```bash
# Test from the auth container
docker compose exec evo-auth curl http://keycloak:8080/realms/organization/protocol/openid-connect/certs
```

Common issues:
- Docker network connectivity between services
- SSL certificate validation (use `KEYCLOAK_SSL_VERIFY=false` in dev with self-signed certs)
- Incorrect internal URL (must point to the Keycloak container, not localhost)

### Token Exchange Failures

Verify the client configuration in Keycloak:
- The client must be **public** (not confidential, without secret)
- PKCE must be enabled
- Redirect URI must match exactly (including port and path)
- The client must have **Standard Flow** enabled

### CORS Errors

- Add the frontend origin to **Web Origins** in the Keycloak client
- Use `+` in Web Origins to allow all subdomains
- Verify that the protocol (http/https) matches

### Role Sync Issues

Verify that `KEYCLOAK_ROLES_CLAIM` matches the structure of your Keycloak token:

```bash
# Inspect auth service logs
docker compose logs evo-auth | grep "Keycloak::UserProvisioner"
```

It should show:
```
[Keycloak::UserProvisioner] realm claim=realm_access.roles roles=["admin", "supervisor"]
```

If the claim is empty, verify:
1. The roles mapper is configured in Keycloak (Client Scopes → roles → Mappers)
2. The user has roles assigned in the realm
3. The claim name in the mapper matches `KEYCLOAK_ROLES_CLAIM`

### Invalid Client Error

- Verify that `VITE_KEYCLOAK_CLIENT_ID` and `KEYCLOAK_CLIENT_ID` exactly match the Client ID in Keycloak
- Ensure the client is in the correct realm
- Verify that the client is not disabled

### "No authorization code received"

- Verify that the callback URL is registered in **Valid Redirect URIs** in Keycloak
- The redirect URI must match exactly (without extra trailing slashes)
- Check error parameters in the URL: `?error=access_denied` or others

## Without Keycloak (Normal Development)

To start the application without SSO authentication:

```bash
docker compose up -d
```

Or with Keycloak disabled in `.env`:
```env
KEYCLOAK_ENABLED=false
VITE_KEYCLOAK_ENABLED=false
```

## Security Considerations

1. **PKCE Required**: Always use PKCE for public clients (required by this implementation)
2. **Server-Side Exchange**: The authorization code is exchanged server-side, never in the browser
3. **JWKS Validation**: All tokens are validated against the Keycloak JWKS endpoint
4. **SSL Verification**: Enable in production (`KEYCLOAK_SSL_VERIFY=true`)
5. **Token Storage**: ID tokens are stored in the DB for secure logout
6. **code_verifier in sessionStorage**: It is automatically cleared when the tab is closed (more secure than localStorage)
7. **Clear Sensitive Data**: Remove `code_verifier` after a successful exchange
8. **Validate state**: Consider adding a `state` parameter for CSRF protection
9. **HTTPS in production**: Never use HTTP in production environments

## References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OAuth 2.0 PKCE](https://oauth.net/2/grant-types/authorization-code-with-pkce/)
- Relevant files:
  - `evo-auth-service-community/lib/keycloak/*.rb`
  - `evo-auth-service-community/app/controllers/api/v1/auth_controller.rb`
  - `evo-ai-frontend-community/src/services/auth/keycloakService.ts`
  - `docker-compose.keycloak-integration.yml`
