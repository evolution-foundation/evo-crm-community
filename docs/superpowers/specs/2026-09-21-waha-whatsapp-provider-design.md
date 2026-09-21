# WAHA as a new WhatsApp provider

Status: approved for planning
Date: 2026-09-21

## Context

`evo-ai-crm-community` already supports multiple WhatsApp providers through a
Strategy pattern: `Channel::Whatsapp::PROVIDERS` lists `whatsapp_cloud`,
`evolution`, `evolution_go`, `notificame`, `zapi`; `Channel::Whatsapp#provider_service`
instantiates the matching class, and every provider subclasses
`Whatsapp::Providers::BaseService`. Per-provider incoming-message handlers
subclass `IncomingMessageBaseService`.

We are adding **WAHA** (https://waha.devlike.pro) as a new provider. WAHA is
a self-hosted, session-based WhatsApp HTTP API (Baileys-family, like
Evolution Go), so `evolution_go` is the closest existing template for both
the provider service and the incoming-message handler.

Since WAHA 2026.6.1, WAHA Core is fully free/open-source with multi-session
support unified in — no license key and no separate "Plus" tier to design
around. One WAHA `session` maps 1:1 to one `Channel::Whatsapp` row, same as
Evolution/Evolution Go instances today. The user confirmed WAHA is
configured purely via `base_url` + `api_key` + `session_name` in
`provider_config`, exactly like Evolution API is today — it does not matter
whether WAHA runs in this stack's docker-compose or on an entirely separate
VPS/host.

### Known bug class to avoid re-introducing

Commit `6c8315b` ("fix(whatsapp): reconcile Evolution API contacts with
divergent phone normalization") fixed a real production bug: the Evolution
API webhook computed `source_id` with an older Brazil-only phone normalizer
that disagreed with `Whatsapp::PhoneNumberNormalizer` (the canonical
normalizer used everywhere else — manual contact creation, leads API,
widget) for DDD ≥ 31 mobiles. This caused the same contact to end up on two
different `ContactInbox` rows, losing pipeline/tags on the manually-created
card.

The fix has two parts, both of which the WAHA implementation must reuse
from day one rather than re-deriving:

1. `ContactInboxWithContactBuilder#reconcilable_whatsapp_channel?` gates a
   smart lookup-by-phone (reuse existing `ContactInbox` on source_id miss)
   for providers prone to source_id drift. Currently
   `%w[evolution_go evolution]`.
2. The incoming-message handler must compute `source_id` via
   `Whatsapp::PhoneNumberNormalizer.call(raw_source_id)`, not a bespoke or
   provider-specific parser.

WAHA is Baileys-based like Evolution/Evolution Go, so it is equally prone to
this drift and must be covered by both fixes from the start.

## Goals

- Add WAHA as a fully functional WhatsApp provider: connect via QR (session
  create/start/QR/status), send text and media, receive inbound messages,
  webhook delivery of status changes.
- Follow the existing Strategy pattern exactly — no new abstractions, no
  changes to how `Channel::Whatsapp` or the rest of the CRM talks to
  providers.
- Ship with the phone-normalization/smart-lookup fix already applied, not
  as a follow-up.

## Non-goals

- Template messages / WhatsApp Business API template sync (WAHA has no
  equivalent concept; `send_template`/`sync_templates` stay unimplemented,
  matching how other non-Cloud providers already leave them out).
- An "Evolution Hub"-style managed multi-instance orchestration layer for
  WAHA. Not needed: WAHA Core is natively multi-session per server, and one
  `Channel::Whatsapp` row already maps to one WAHA session the same way it
  maps to one Evolution instance.
- Passkey-based WAHA auth (`/auth/passkey/*` endpoints) — QR and
  pairing-code auth cover the CRM's connect flow; passkey auth is out of
  scope for this pass.

## Design

### 1. Provider registration

- `app/models/channel/whatsapp.rb`: add `'waha'` to `PROVIDERS`; add a
  branch in `provider_service` instantiating `Whatsapp::Providers::WahaService`.
- `provider_config` (jsonb) fields: `waha_base_url`, `waha_api_key`,
  `session_name`. `waha_api_key` is sent as the `X-Api-Key` header on every
  request, matching WAHA's documented auth scheme.

### 2. `Whatsapp::Providers::WahaService < BaseService`

File: `app/services/whatsapp/providers/waha_service.rb`, modeled on
`evolution_go_service.rb`.

- `send_message`: `POST /api/sendText` for plain text; `POST /api/sendImage`
  / `sendFile` / `sendVoice` / `sendVideo` chosen by attachment content
  type, mirroring how `evolution_go_service.rb` branches today. Every call
  includes `session: session_name` and `chatId` in the body.
- `validate_provider_config`: `GET /api/sessions/{session}` — confirms the
  base URL, API key, and session name are reachable/valid.
- Connection/QR lifecycle:
  1. `POST /api/sessions` on first connect — body includes `name:
     session_name`, `start: true`, and `config.webhooks` pointed at the new
     WAHA webhook endpoint (see §4) with `events: ['message',
     'session.status']`.
  2. `GET /api/sessions/{session}` polled for status
     (`STARTING`/`SCAN_QR_CODE`/`WORKING`/`FAILED`/`STOPPED`), same polling
     pattern the frontend already uses for Evolution connect flows.
  3. `GET /api/{session}/auth/qr?format=raw` returns the QR as base64 while
     status is `SCAN_QR_CODE`.
  4. Optional pairing-code path: `POST /api/{session}/auth/request-code`
     with a phone number, as an alternative to scanning, surfaced as a
     secondary option in the connect UI (not the default flow).
  5. `POST /api/sessions/{session}/logout` / `DELETE /api/sessions/{session}`
     for disconnect/channel deletion.
- `send_template` / `sync_templates`: left unimplemented (see Non-goals).

Exact webhook JSON payload for the `message` event isn't in WAHA's public
OpenAPI spec. Implementation will confirm the real shape against a live
WAHA container (or WAHA's GitHub docs/examples) before finalizing the
incoming-message parser — flagged as an implementation-time verification
step, not a design ambiguity to resolve now.

### 3. `Whatsapp::IncomingMessageWahaService < IncomingMessageBaseService`

File: `app/services/whatsapp/incoming_message_waha_service.rb`, modeled on
`incoming_message_evolution_go_service.rb`.

- Parses the `message` webhook event into the CRM's normalized
  contact/message model.
- **Must** compute `source_id` via
  `Whatsapp::PhoneNumberNormalizer.call(raw_source_id) || raw_source_id`
  from the WAHA payload's chat/JID field — not a bespoke parser — per the
  "known bug class" section above.
- Session/status-change events (`session.status`) update
  `Channel::Whatsapp#provider_connection`, same as Evolution's status
  webhook handling.

### 4. Webhook routing

Per prior decision: a **new dedicated route**, not payload-shape sniffing
on the shared endpoint.

- `config/routes.rb`: `POST /webhooks/whatsapp/waha`.
- New `Webhooks::Whatsapp::WahaController` (or equivalent) validates the
  webhook (HMAC signature, using WAHA's `config.webhooks[].hmac.key` set at
  session-creation time) and enqueues the existing
  `Webhooks::WhatsappEventsJob` tagged so it dispatches to
  `IncomingMessageWahaService`.

### 5. Session/QR API endpoints (CRM-facing, for the connect UI)

- `api/v1/whatsapp/waha/{qrcodes,instances}` controllers, mirroring
  `evolution_go`'s existing routes, delegating to `WahaService`.

### 6. Frontend (`evo-ai-frontend-community`)

- New provider option in the channel-type selector
  (`ChannelTypeCard.tsx` / `NewChannel/index.tsx`).
- `src/services/integrations/wahaService.ts`, analogous to
  `evolutionHubService.ts`, calling the new backend endpoints.
- Reuse existing QR-display / status-polling connect-flow components
  (`HubConnectButton.tsx` and friends) — no new UI patterns needed.

### 7. Deployment

- `docker-compose.dokploy.yaml`: add a `waha` service block (image
  `devlikeapro/waha:latest`), `WAHA_API_KEY` env, a volume for session
  persistence — alongside the existing `evolution-api` block. This is for
  convenience/self-hosting in this stack; per the confirmed requirement,
  nothing in the design requires WAHA to run inside this compose file —
  `provider_config.waha_base_url` can point anywhere reachable.

### Known-bug fix carried into this feature

- `app/builders/contact_inbox_with_contact_builder.rb`:
  `reconcilable_whatsapp_channel?` becomes `%w[evolution_go evolution waha]`
  so WAHA gets the same smart-lookup-by-phone reconciliation.
- `IncomingMessageWahaService` built from the start on
  `Whatsapp::PhoneNumberNormalizer.call`, never a provider-specific
  normalizer.

## Testing

- RSpec unit tests for `WahaService` (HTTP calls mocked): send text/media,
  connect lifecycle (create → start → QR → status poll), config validation.
- RSpec tests for `IncomingMessageWahaService` using a captured/synthetic
  WAHA `message` webhook payload, including a DDD ≥ 31 phone-number case
  matching the existing `contact_inbox_with_contact_builder_spec.rb` /
  `incoming_message_evolution_service_individual_contact_spec.rb`
  regression tests added in `6c8315b`, adapted for WAHA.
- Webhook controller test: HMAC validation, correct job enqueue.
- Full `whatsapp/builders/contacts/webhooks` spec suite run to confirm no
  regression, same as the Evolution API fix's verification step.
- Manual end-to-end verification against a real WAHA container: QR pairing,
  send/receive text and one media type.

## Open items for implementation time (not design ambiguities)

- Confirm the exact `message` webhook payload shape against a live WAHA
  instance (OpenAPI spec doesn't document it).
- Confirm WAHA's HMAC webhook-signature header name/format for the
  controller's validation step.
