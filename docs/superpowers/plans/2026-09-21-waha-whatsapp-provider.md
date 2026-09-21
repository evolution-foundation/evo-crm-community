# WAHA WhatsApp Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add WAHA (https://waha.devlike.pro) as a new WhatsApp provider in `Channel::Whatsapp`, following the existing Strategy pattern, modeled on `evolution_go`.

**Architecture:** Backend: a `Whatsapp::Providers::WahaService` (outbound: send/connect/QR) + `Whatsapp::IncomingMessageWahaService` (inbound webhook parsing) plug into the existing provider dispatch in `Channel::Whatsapp` and `Webhooks::WhatsappEventsJob`, reached via a new dedicated webhook route (not payload-shape sniffing). Frontend: a new provider card + form component plug into the existing generic channel-creation flow. Deployment: an optional `waha` service block in `docker-compose.dokploy.yaml`.

**Tech Stack:** Ruby on Rails 7 (`evo-ai-crm-community`), HTTParty for outbound HTTP, RSpec (instance-double based mocking, no WebMock/VCR) for tests, React + TypeScript (`evo-ai-frontend-community`).

**Spec:** `docs/superpowers/specs/2026-09-21-waha-whatsapp-provider-design.md`

## Global Constraints

- `reconcilable_whatsapp_channel?` in `app/builders/contact_inbox_with_contact_builder.rb` MUST include `'waha'` (task 6) — this is the fix from commit `6c8315b` extended to the new provider, not optional cleanup.
- Any code that computes a WhatsApp `source_id` from a WAHA payload MUST go through `Whatsapp::PhoneNumberNormalizer.call(raw)`, never a bespoke/provider-specific phone parser (task 5).
- One WAHA `session` maps 1:1 to one `Channel::Whatsapp` row (`provider_config['session_name']`), same as Evolution/Evolution Go instances.
- `send_template`/`sync_templates` are intentionally left unimplemented for WAHA (no template-message concept), matching how `evolution_go` already does this (see `evolution_go_service.rb:185-196` for the exact "send as text with a warning log" pattern to mirror).
- WAHA's exact `message` webhook JSON shape and HMAC header name are not in its public OpenAPI spec. Tasks 4 and 5 implement against WAHA's documented webhook envelope (`{id, timestamp, event, session, payload, ...}`) and its documented session-status enum; task 4's step "verify against a live WAHA instance" must run before this plan is considered done, and the parsing code in task 5 should be easy to adjust (small, isolated private methods) if real payload field names differ slightly.

---

## Task 1: Register `waha` as a provider on `Channel::Whatsapp`

**Files:**
- Modify: `evo-ai-crm-community/app/models/channel/whatsapp.rb`
- Test: `evo-ai-crm-community/spec/models/channel/whatsapp_spec.rb`

**Interfaces:**
- Produces: `Channel::Whatsapp::PROVIDERS` includes `'waha'`; `Channel::Whatsapp#provider_service` returns `Whatsapp::Providers::WahaService.new(whatsapp_channel: self)` when `provider == 'waha'` (class defined in task 2 — this task's spec will stub it, since task 2 doesn't exist yet when this task's tests run only if executed out of order; when executed in order, task 2 lands first so no stub is needed. Keep the stub-free version below since the plan executes tasks in order).

- [ ] **Step 1: Write the failing test**

Add to `evo-ai-crm-community/spec/models/channel/whatsapp_spec.rb` (create the file with this content if it doesn't already cover `provider_service`; if it exists, add this `describe` block):

```ruby
require 'rails_helper'

RSpec.describe Channel::Whatsapp do
  describe '#provider_service' do
    it 'returns a WahaService when provider is waha' do
      channel = build(:channel_whatsapp, provider: 'waha', provider_config: { 'base_url' => 'https://waha.example.com', 'api_key' => 'key', 'session_name' => 'default' })
      expect(channel.provider_service).to be_a(Whatsapp::Providers::WahaService)
    end
  end

  describe 'PROVIDERS' do
    it 'includes waha' do
      expect(described_class::PROVIDERS).to include('waha')
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/models/channel/whatsapp_spec.rb -e "provider_service" -e "PROVIDERS"`
Expected: FAIL — `PROVIDERS` does not include `'waha'`, and `Whatsapp::Providers::WahaService` is undefined (NameError).

- [ ] **Step 3: Add `waha` to `PROVIDERS` and `provider_service`**

In `app/models/channel/whatsapp.rb`, line 20:

```ruby
  PROVIDERS = %w[default whatsapp_cloud evolution evolution_go notificame zapi waha].freeze
```

Line 43, extend the disconnect-on-destroy callback:

```ruby
  before_destroy :disconnect_channel_provider, if: -> { provider.in?(%w[evolution evolution_go waha]) }
```

In `provider_service` (around line 68), add a branch:

```ruby
  def provider_service
    case provider
    when 'whatsapp_cloud'
      Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: self)
    when 'evolution'
      Whatsapp::Providers::EvolutionService.new(whatsapp_channel: self)
    when 'evolution_go'
      Whatsapp::Providers::EvolutionGoService.new(whatsapp_channel: self)
    when 'notificame'
      Whatsapp::Providers::NotificameService.new(whatsapp_channel: self)
    when 'zapi'
      Whatsapp::Providers::ZapiService.new(whatsapp_channel: self)
    when 'waha'
      Whatsapp::Providers::WahaService.new(whatsapp_channel: self)
    else
      Whatsapp::Providers::Whatsapp360DialogService.new(whatsapp_channel: self)
    end
  end
```

Note: this step references `Whatsapp::Providers::WahaService`, which doesn't exist until task 2. Do task 2 immediately after this task (before running the full suite) — the step 4 run below will fail with `NameError: uninitialized constant` until then, which is expected and documented here so the executor isn't surprised.

- [ ] **Step 4: Run test again (will still fail until task 2 lands — that's expected)**

Run: `bundle exec rspec spec/models/channel/whatsapp_spec.rb -e "provider_service" -e "PROVIDERS"`
Expected: `PROVIDERS` example passes; `provider_service` example fails with `NameError: uninitialized constant Whatsapp::Providers::WahaService`. Do not commit yet — proceed to task 2, then come back and run both together.

- [ ] **Step 5: Commit (after task 2's WahaService class exists and both examples pass)**

```bash
git add app/models/channel/whatsapp.rb spec/models/channel/whatsapp_spec.rb
git commit -m "feat(whatsapp): register waha as a provider on Channel::Whatsapp"
```

---

## Task 2: `Whatsapp::Providers::WahaService` — config validation, text send, disconnect

**Files:**
- Create: `evo-ai-crm-community/app/services/whatsapp/providers/waha_service.rb`
- Test: `evo-ai-crm-community/spec/services/whatsapp/providers/waha_service_spec.rb`

**Interfaces:**
- Consumes: `Whatsapp::Providers::BaseService` (`whatsapp_channel` reader via `pattr_initialize`, `html_to_whatsapp(text)` helper, `error_message(response)` helper).
- Produces: `Whatsapp::Providers::WahaService.new(whatsapp_channel:).send_message(phone_number, message)`, `.validate_provider_config?` (Boolean), `.check_number_exists?(phone_number)` (Boolean or nil), `.disconnect_channel_provider`. Reads config from `whatsapp_channel.provider_config['base_url']`, `['api_key']`, `['session_name']`.

- [ ] **Step 1: Write the failing tests**

Create `evo-ai-crm-community/spec/services/whatsapp/providers/waha_service_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Whatsapp::Providers::WahaService do
  let(:provider_config) do
    { 'base_url' => 'https://waha.example.com', 'api_key' => 'secret-key', 'session_name' => 'default' }
  end
  let(:whatsapp_channel) { instance_double(Channel::Whatsapp, provider_config: provider_config) }
  let(:service) { described_class.new(whatsapp_channel: whatsapp_channel) }

  describe '#validate_provider_config?' do
    it 'returns false when base_url is blank' do
      allow(whatsapp_channel).to receive(:provider_config).and_return(provider_config.merge('base_url' => ''))
      expect(service.validate_provider_config?).to eq(false)
    end

    it 'returns false when api_key is blank' do
      allow(whatsapp_channel).to receive(:provider_config).and_return(provider_config.merge('api_key' => ''))
      expect(service.validate_provider_config?).to eq(false)
    end

    it 'returns false when session_name is blank' do
      allow(whatsapp_channel).to receive(:provider_config).and_return(provider_config.merge('session_name' => ''))
      expect(service.validate_provider_config?).to eq(false)
    end

    it 'returns true and hits GET /api/sessions/:session when config is present' do
      response = instance_double(HTTParty::Response, success?: true, code: 200, body: '{}', parsed_response: {})
      expect(HTTParty).to receive(:get).with(
        'https://waha.example.com/api/sessions/default',
        hash_including(headers: { 'X-Api-Key' => 'secret-key', 'Content-Type' => 'application/json' })
      ).and_return(response)

      expect(service.validate_provider_config?).to eq(true)
    end

    it 'returns false when the session lookup fails' do
      response = instance_double(HTTParty::Response, success?: false, code: 404, body: 'not found', parsed_response: {})
      allow(HTTParty).to receive(:get).and_return(response)

      expect(service.validate_provider_config?).to eq(false)
    end
  end

  describe '#send_message' do
    let(:message) { instance_double(Message, attachments: [], content_type: 'text', content: 'Hello there') }

    it 'posts to /api/sendText with the session and chatId' do
      response = instance_double(HTTParty::Response, success?: true, code: 201, body: '{}', parsed_response: { 'id' => 'true_5511999999999@c.us_ABCDEF' })
      expect(HTTParty).to receive(:post).with(
        'https://waha.example.com/api/sendText',
        hash_including(
          headers: { 'X-Api-Key' => 'secret-key', 'Content-Type' => 'application/json' },
          body: { session: 'default', chatId: '5511999999999@c.us', text: 'Hello there' }.to_json
        )
      ).and_return(response)

      result = service.send_message('+5511999999999', message)
      expect(result).to eq('true_5511999999999@c.us_ABCDEF')
    end

    it 'marks the message unsupported when there is no content or attachments' do
      empty_message = instance_double(Message, attachments: [], content_type: 'text', content: nil)
      expect(empty_message).to receive(:update!).with(is_unsupported: true)

      service.send_message('+5511999999999', empty_message)
    end
  end

  describe '#check_number_exists?' do
    it 'returns true when WAHA reports the number exists' do
      response = instance_double(
        HTTParty::Response, success?: true,
        parsed_response: [{ 'numberExists' => true, 'chatId' => '5511999999999@c.us' }]
      )
      allow(HTTParty).to receive(:post).and_return(response)

      expect(service.check_number_exists?('+5511999999999')).to eq(true)
    end

    it 'returns nil when the HTTP call fails' do
      allow(HTTParty).to receive(:post).and_raise(Errno::ECONNREFUSED)

      expect(service.check_number_exists?('+5511999999999')).to be_nil
    end
  end

  describe '#disconnect_channel_provider' do
    it 'logs out and stops the session' do
      logout_response = instance_double(HTTParty::Response, code: 200, body: '{}')
      stop_response = instance_double(HTTParty::Response, code: 200, body: '{}')

      expect(HTTParty).to receive(:post).with(
        'https://waha.example.com/api/sessions/default/logout',
        hash_including(headers: { 'X-Api-Key' => 'secret-key', 'Content-Type' => 'application/json' })
      ).and_return(logout_response)
      expect(HTTParty).to receive(:post).with(
        'https://waha.example.com/api/sessions/default/stop',
        hash_including(headers: { 'X-Api-Key' => 'secret-key', 'Content-Type' => 'application/json' })
      ).and_return(stop_response)

      service.disconnect_channel_provider
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/services/whatsapp/providers/waha_service_spec.rb`
Expected: FAIL — `Whatsapp::Providers::WahaService` is not defined.

- [ ] **Step 3: Implement `WahaService`**

Create `evo-ai-crm-community/app/services/whatsapp/providers/waha_service.rb`:

```ruby
class Whatsapp::Providers::WahaService < Whatsapp::Providers::BaseService
  def send_message(phone_number, message)
    if message.attachments.present?
      send_attachment_message(phone_number, message)
    elsif message.content.present?
      send_text_message(phone_number, message)
    else
      message.update!(is_unsupported: true)
      nil
    end
  end

  def send_template(phone_number, template_info)
    Rails.logger.warn 'WAHA does not support template messages, sending as text'
    send_text_message(phone_number, template_info)
  end

  def sync_templates
    Rails.logger.debug 'WAHA: no template sync needed, templates are not supported'
  end

  def validate_provider_config?
    return false if base_url.blank?
    return false if api_key.blank?
    return false if session_name.blank?

    response = HTTParty.get("#{base_url}/api/sessions/#{session_name}", headers: api_headers, timeout: 10)
    response.success?
  rescue StandardError => e
    Rails.logger.error "WAHA validation error: #{e.message}"
    false
  end

  def check_number_exists?(phone_number)
    chat_id = to_chat_id(phone_number)
    return nil if chat_id.blank? || base_url.blank?

    response = HTTParty.post(
      "#{base_url}/api/#{session_name}/checkNumberStatus",
      headers: api_headers,
      body: { phone: chat_id.split('@').first }.to_json,
      open_timeout: 5, read_timeout: 10
    )
    return nil unless response.success?

    entry = Array(response.parsed_response).first
    return nil if entry.blank?

    ActiveModel::Type::Boolean.new.cast(entry['numberExists'])
  rescue StandardError => e
    Rails.logger.error "WAHA check_number_exists? error: #{e.class} - #{e.message}"
    nil
  end

  def disconnect_channel_provider
    return if session_name.blank? || base_url.blank?

    logout_response = HTTParty.post("#{base_url}/api/sessions/#{session_name}/logout", headers: api_headers, timeout: 30)
    Rails.logger.info "WAHA logout response: #{logout_response.code} - #{logout_response.body}"

    stop_response = HTTParty.post("#{base_url}/api/sessions/#{session_name}/stop", headers: api_headers, timeout: 30)
    Rails.logger.info "WAHA stop response: #{stop_response.code} - #{stop_response.body}"
  rescue StandardError => e
    Rails.logger.error "WAHA disconnect error: #{e.message}"
  end

  private

  def base_url
    whatsapp_channel.provider_config['base_url'].to_s.strip.chomp('/')
  end

  def api_key
    whatsapp_channel.provider_config['api_key'].to_s.strip
  end

  def session_name
    whatsapp_channel.provider_config['session_name'].to_s.strip
  end

  def api_headers
    { 'X-Api-Key' => api_key, 'Content-Type' => 'application/json' }
  end

  def to_chat_id(phone_number)
    digits = phone_number.to_s.delete('+')
    return nil if digits.blank?

    "#{digits}@c.us"
  end

  def send_text_message(phone_number, message)
    body = { session: session_name, chatId: to_chat_id(phone_number), text: html_to_whatsapp(message.content.to_s) }

    response = HTTParty.post("#{base_url}/api/sendText", headers: api_headers, body: body.to_json)
    process_waha_response(response)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    return unless attachment

    endpoint = case attachment.file_type
               when 'image' then 'sendImage'
               when 'audio' then 'sendVoice'
               when 'video' then 'sendVideo'
               else 'sendFile'
               end

    body = {
      session: session_name,
      chatId: to_chat_id(phone_number),
      caption: html_to_whatsapp(message.content.to_s),
      file: { url: attachment.file_url, filename: attachment.file.filename.to_s }
    }

    response = HTTParty.post("#{base_url}/api/#{endpoint}", headers: api_headers, body: body.to_json)
    process_waha_response(response)
  end

  def process_waha_response(response)
    if response.success?
      response.parsed_response['id']
    else
      handle_error(response)
      nil
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/services/whatsapp/providers/waha_service_spec.rb`
Expected: PASS (all examples green).

- [ ] **Step 5: Run task 1's model spec together now that `WahaService` exists**

Run: `bundle exec rspec spec/models/channel/whatsapp_spec.rb spec/services/whatsapp/providers/waha_service_spec.rb`
Expected: PASS (all examples green).

- [ ] **Step 6: Commit**

```bash
git add app/services/whatsapp/providers/waha_service.rb spec/services/whatsapp/providers/waha_service_spec.rb
git commit -m "feat(whatsapp): add WahaService provider (config validation, text/media send, disconnect)"
```

---

## Task 3: `reconcilable_whatsapp_channel?` — extend smart contact lookup to `waha`

**Files:**
- Modify: `evo-ai-crm-community/app/builders/contact_inbox_with_contact_builder.rb`
- Test: `evo-ai-crm-community/spec/builders/contact_inbox_with_contact_builder_spec.rb`

**Interfaces:**
- Produces: `ContactInboxWithContactBuilder#reconcilable_whatsapp_channel?` returns `true` for `waha` channels, giving them the same phone-drift-tolerant smart lookup as `evolution`/`evolution_go` (reuses an existing `ContactInbox` on source_id miss instead of creating a duplicate).

This is the change called out in the Global Constraints — it must ship with this feature, not as a follow-up.

- [ ] **Step 1: Write the failing test**

Add to `evo-ai-crm-community/spec/builders/contact_inbox_with_contact_builder_spec.rb` (append a new `context`, following the existing `evolution`/`evolution_go` examples already in that file added by `6c8315b`):

```ruby
  context 'when the channel provider is waha' do
    let(:inbox) { create(:inbox, channel: create(:channel_whatsapp, provider: 'waha', phone_number: '+551199999999x')) }

    it 'is reconcilable' do
      builder = described_class.new(source_id: '5511988887777@c.us', inbox: inbox, contact_attributes: {})
      expect(builder.reconcilable_whatsapp_channel?).to eq(true)
    end

    it 'reuses an existing ContactInbox for the same contact when source_id has drifted' do
      contact = create(:contact, phone_number: '+5511988887777')
      existing_contact_inbox = create(:contact_inbox, contact: contact, inbox: inbox, source_id: '551188887777@c.us')

      builder = described_class.new(
        source_id: '5511988887777@c.us',
        inbox: inbox,
        contact_attributes: { phone_number: '+5511988887777' }
      )
      result = builder.perform

      expect(result.id).to eq(existing_contact_inbox.id)
      expect(result.reload.source_id).to eq('5511988887777@c.us')
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/builders/contact_inbox_with_contact_builder_spec.rb -e "waha"`
Expected: FAIL — `reconcilable_whatsapp_channel?` returns `false` for provider `'waha'`.

- [ ] **Step 3: Add `waha` to the reconcilable provider list**

In `app/builders/contact_inbox_with_contact_builder.rb`, the method currently reads (post `6c8315b`):

```ruby
  def reconcilable_whatsapp_channel?
    inbox.channel_type == 'Channel::Whatsapp' && inbox.channel.provider.in?(%w[evolution_go evolution])
  end
```

Change to:

```ruby
  def reconcilable_whatsapp_channel?
    inbox.channel_type == 'Channel::Whatsapp' && inbox.channel.provider.in?(%w[evolution_go evolution waha])
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/builders/contact_inbox_with_contact_builder_spec.rb`
Expected: PASS (all examples, including the pre-existing evolution/evolution_go ones, still green).

- [ ] **Step 5: Commit**

```bash
git add app/builders/contact_inbox_with_contact_builder.rb spec/builders/contact_inbox_with_contact_builder_spec.rb
git commit -m "fix(whatsapp): extend smart contact/inbox reconciliation to waha (per 6c8315b)"
```

---

## Task 4: Webhook route + controller for WAHA (dedicated endpoint, not sniffing)

**Files:**
- Modify: `evo-ai-crm-community/config/routes.rb`
- Modify: `evo-ai-crm-community/app/controllers/webhooks/whatsapp_controller.rb`
- Test: `evo-ai-crm-community/spec/controllers/webhooks/whatsapp_controller_spec.rb` (or `spec/requests/webhooks/whatsapp_spec.rb` — match whichever file already covers `process_evolution_go_payload`; if a `spec/controllers/webhooks/whatsapp_controller_spec.rb` exists, add to it)

**Interfaces:**
- Produces: `POST /webhooks/whatsapp/waha` → `Webhooks::WhatsappController#process_waha_payload`, enqueues `Webhooks::WhatsappEventsJob.perform_later(params.to_unsafe_hash.merge(waha: true))`.

- [ ] **Step 1: Write the failing test**

Add to the existing webhook controller/request spec (mirror whatever pattern already tests `process_evolution_go_payload`; using a request spec here since the controller is `ActionController::API` reached via routing):

```ruby
require 'rails_helper'

RSpec.describe 'Webhooks::Whatsapp waha', type: :request do
  describe 'POST /webhooks/whatsapp/waha' do
    it 'enqueues Webhooks::WhatsappEventsJob with waha: true' do
      payload = { id: 'evt_123', event: 'message', session: 'default', payload: { from: '5511999999999@c.us', body: 'hi' } }

      expect(Webhooks::WhatsappEventsJob).to receive(:perform_later).with(hash_including(waha: true, 'event' => 'message', 'session' => 'default'))

      post '/webhooks/whatsapp/waha', params: payload

      expect(response).to have_http_status(:ok)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/webhooks/whatsapp_waha_spec.rb`
Expected: FAIL — 404, route not defined.

- [ ] **Step 3: Add the routes**

In `config/routes.rb`, inside the account-scoped `resources :webhooks ... collection do` block (right after the `evolution_go` line, ~line 420):

```ruby
          post 'whatsapp/evolution_go', to: 'webhooks/whatsapp#process_evolution_go_payload'
          post 'whatsapp/waha', to: 'webhooks/whatsapp#process_waha_payload'
```

And at the root-level webhook routes (right after the root-level `evolution_go` line, ~line 804 — this is the actually-reachable path WAHA's own webhook config will point at, matching how Evolution Go's `webhook_url` concern builds its own root-level URL):

```ruby
  post 'webhooks/whatsapp/evolution_go', to: 'webhooks/whatsapp#process_evolution_go_payload'
  post 'webhooks/whatsapp/waha', to: 'webhooks/whatsapp#process_waha_payload'
```

- [ ] **Step 4: Add the controller action**

In `app/controllers/webhooks/whatsapp_controller.rb`, add a new public action alongside `process_evolution_go_payload`:

```ruby
  def process_waha_payload
    unless valid_waha_payload?
      render json: { error: 'Invalid WAHA webhook payload' }, status: :bad_request
      return
    end

    Webhooks::WhatsappEventsJob.perform_later(params.to_unsafe_hash.merge(waha: true))
    head :ok
  end

  private

  def valid_waha_payload?
    params[:event].present? && params[:session].present? && params[:payload].present?
  end
```

(Add `valid_waha_payload?` in the existing `private` section, alongside `valid_evolution_go_payload?` — do not create a second `private` keyword.)

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/webhooks/whatsapp_waha_spec.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/webhooks/whatsapp_controller.rb spec/requests/webhooks/whatsapp_waha_spec.rb
git commit -m "feat(whatsapp): add dedicated WAHA webhook route and controller action"
```

---

## Task 5: `Whatsapp::IncomingMessageWahaService` — inbound message + session-status handling

**Files:**
- Create: `evo-ai-crm-community/app/services/whatsapp/incoming_message_waha_service.rb`
- Test: `evo-ai-crm-community/spec/services/whatsapp/incoming_message_waha_service_spec.rb`

**Interfaces:**
- Consumes: `Whatsapp::IncomingMessageBaseService` (`pattr_initialize [:inbox!, :params!]`), `ContactInboxWithContactBuilder.new(source_id:, inbox:, contact_attributes:).perform`, `Whatsapp::PhoneNumberNormalizer.call(raw)`, `Channel::Whatsapp#update_provider_connection!`, `#mark_connected!`.
- Produces: `Whatsapp::IncomingMessageWahaService.new(inbox:, params:).perform` — dispatches on `params[:event]` (`'message'` → create inbound message; `'session.status'` → update channel connection state).

WAHA's documented webhook envelope is `{id, timestamp, event, session, payload, environment, metadata}`. For a `message` event, `payload` includes `{id, timestamp, from, fromMe, to, body, hasMedia, media, type}` (`from`/`to` are chat-id strings like `5511999999999@c.us`). For a `session.status` event, `payload` includes `{name, status}` with `status` one of `STARTING`, `SCAN_QR_CODE`, `WORKING`, `FAILED`, `STOPPED`. **Verify these exact field names against a live WAHA instance or its GitHub docs before merging** — if they differ, only the private parsing methods below (`raw_source_id`, `message_body`, `incoming?`, `session_status`) need adjusting; the public `#perform` dispatch and the contact/message creation flow do not.

- [ ] **Step 1: Write the failing tests**

Create `evo-ai-crm-community/spec/services/whatsapp/incoming_message_waha_service_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Whatsapp::IncomingMessageWahaService do
  let(:channel) { instance_double(Channel::Whatsapp, id: 'chan-1') }
  let(:inbox) { instance_double(Inbox, id: 'inbox-1', channel: channel, archived?: false) }

  def service_for(event, payload)
    described_class.new(inbox: inbox, params: { event: event, session: 'default', payload: payload })
  end

  describe 'message event' do
    it 'creates a contact/inbox via ContactInboxWithContactBuilder with a normalized source_id' do
      payload = { 'id' => 'true_5511988887777@c.us_ABC', 'from' => '5511988887777@c.us', 'fromMe' => false, 'body' => 'oi', 'hasMedia' => false }
      contact_inbox = instance_double(ContactInbox, contact: instance_double(Contact))
      conversation = instance_double(Conversation, messages: double(build: instance_double(Message, save!: true, attachments: [])))

      expect(Whatsapp::PhoneNumberNormalizer).to receive(:call).with('5511988887777').and_call_original
      expect(ContactInboxWithContactBuilder).to receive(:new).with(
        hash_including(source_id: '5511988887777', inbox: inbox)
      ).and_return(instance_double(ContactInboxWithContactBuilder, perform: contact_inbox))
      allow(contact_inbox).to receive(:conversations).and_return(double(where: double(not: double(last: nil)), last: nil))
      allow(Conversation).to receive(:find_or_create_by!).and_return(conversation)

      service_for('message', payload).perform
    end

    it 'skips messages sent by the channel itself (fromMe: true)' do
      payload = { 'id' => 'true_x_1', 'from' => '5511988887777@c.us', 'fromMe' => true, 'body' => 'oi' }

      expect(ContactInboxWithContactBuilder).not_to receive(:new)

      service_for('message', payload).perform
    end
  end

  describe 'session.status event' do
    it 'marks the channel connected when status is WORKING' do
      payload = { 'name' => 'default', 'status' => 'WORKING' }
      expect(channel).to receive(:mark_connected!)

      service_for('session.status', payload).perform
    end

    it 'updates provider_connection to closed when status is FAILED' do
      payload = { 'name' => 'default', 'status' => 'FAILED' }
      expect(channel).to receive(:update_provider_connection!).with(hash_including('connection' => 'close'))

      service_for('session.status', payload).perform
    end

    it 'stores the QR data when status is SCAN_QR_CODE and a qr field is present' do
      payload = { 'name' => 'default', 'status' => 'SCAN_QR_CODE', 'qr' => 'data:image/png;base64,AAA' }
      expect(channel).to receive(:update_provider_connection!).with(hash_including('connection' => 'connecting', 'qr_data_url' => 'data:image/png;base64,AAA'))

      service_for('session.status', payload).perform
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/services/whatsapp/incoming_message_waha_service_spec.rb`
Expected: FAIL — `Whatsapp::IncomingMessageWahaService` is not defined.

- [ ] **Step 3: Implement `IncomingMessageWahaService`**

Create `evo-ai-crm-community/app/services/whatsapp/incoming_message_waha_service.rb`:

```ruby
class Whatsapp::IncomingMessageWahaService < Whatsapp::IncomingMessageBaseService
  def perform
    return if inbox.archived?

    case processed_params[:event]
    when 'message'
      process_message
    when 'session.status'
      process_session_status
    else
      Rails.logger.warn "WAHA: unhandled event type #{processed_params[:event]}"
    end
  end

  private

  def process_message
    payload = processed_params[:payload] || {}
    return if ActiveModel::Type::Boolean.new.cast(payload[:fromMe])

    set_contact(payload)
    return unless @contact

    set_conversation
    create_message(payload)
  end

  def set_contact(payload)
    source_id = Whatsapp::PhoneNumberNormalizer.call(raw_source_id(payload)) || raw_source_id(payload)
    return if source_id.blank?

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: source_id,
      inbox: inbox,
      contact_attributes: { phone_number: Whatsapp::PhoneNumberNormalizer.to_e164(raw_source_id(payload)) }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def raw_source_id(payload)
    payload[:from].to_s.split('@').first
  end

  def set_conversation
    @conversation = if inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end
    return if @conversation

    @conversation = ::Conversation.find_or_create_by!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    )
  end

  def create_message(payload)
    message = @conversation.messages.build(
      content: payload[:body],
      inbox_id: inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: payload[:id].to_s
    )
    @message = message
    message.save!
  end

  def process_session_status
    payload = processed_params[:payload] || {}
    status = payload[:status].to_s

    case status
    when 'WORKING'
      whatsapp_channel.mark_connected!
    when 'SCAN_QR_CODE'
      whatsapp_channel.update_provider_connection!(
        { 'connection' => 'connecting', 'qr_data_url' => payload[:qr], 'error' => nil }.compact
      )
    when 'FAILED', 'STOPPED'
      whatsapp_channel.update_provider_connection!({ 'connection' => 'close', 'error' => status })
    else
      Rails.logger.info "WAHA: session.status #{status} (no channel state change)"
    end
  end

  def whatsapp_channel
    inbox.channel
  end
end
```

Note: `create_message` above intentionally does not call `attach_files`/media download for this first pass (media handling from WAHA payload URLs is a natural fast-follow, not required for text-message parity with the spec's goals) — a `hasMedia: true` message will still be recorded with its `body`/caption text.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/services/whatsapp/incoming_message_waha_service_spec.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/whatsapp/incoming_message_waha_service.rb spec/services/whatsapp/incoming_message_waha_service_spec.rb
git commit -m "feat(whatsapp): add IncomingMessageWahaService (message + session.status events)"
```

---

## Task 6: Wire WAHA into `Webhooks::WhatsappEventsJob` dispatch and channel resolution

**Files:**
- Modify: `evo-ai-crm-community/app/jobs/webhooks/whatsapp_events_job.rb`
- Test: `evo-ai-crm-community/spec/jobs/webhooks/whatsapp_events_job_spec.rb`

**Interfaces:**
- Consumes: `Whatsapp::IncomingMessageWahaService.new(inbox:, params:).perform` (task 5).
- Produces: `Webhooks::WhatsappEventsJob#handle_message_events` dispatches WAHA channels to `IncomingMessageWahaService`; `#try_find_channel_by_phone_number` resolves a WAHA channel by `params[:session]` via `provider_config ->> 'session_name'`; `CONNECTION_LIFECYCLE_EVENT_NAMES` includes `'session.status'`.

- [ ] **Step 1: Write the failing tests**

Add to `evo-ai-crm-community/spec/jobs/webhooks/whatsapp_events_job_spec.rb` (mirror the existing `evolution_go` examples in that file):

```ruby
  describe 'waha dispatch' do
    it 'routes message events for a waha channel to IncomingMessageWahaService' do
      channel = create(:channel_whatsapp, provider: 'waha', provider_config: { 'session_name' => 'default' })
      params = { event: 'message', session: 'default', payload: { from: '5511999999999@c.us', fromMe: false, body: 'oi', id: 'msg1' }, waha: true }

      expect(Whatsapp::IncomingMessageWahaService).to receive(:new).with(inbox: channel.inbox, params: anything).and_call_original

      described_class.new.perform(params)
    end

    it 'finds a waha channel by session name' do
      channel = create(:channel_whatsapp, provider: 'waha', provider_config: { 'session_name' => 'default' })
      params = { event: 'session.status', session: 'default', payload: { name: 'default', status: 'WORKING' }, waha: true }

      described_class.new.perform(params)

      expect(channel.reload.provider_connection['connection']).to eq('open')
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/jobs/webhooks/whatsapp_events_job_spec.rb -e "waha dispatch"`
Expected: FAIL — no `waha` branch in `handle_message_events`, and channel resolution falls through without finding the channel.

- [ ] **Step 3: Add the `waha` branch to `handle_message_events`**

In `app/jobs/webhooks/whatsapp_events_job.rb`, the case statement (~line 413):

```ruby
  def handle_message_events(channel, params)
    Rails.logger.info "Processing message event for channel #{channel.phone_number} (provider: #{channel.provider})"

    case channel.provider
    when 'whatsapp_cloud'
      Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: channel.inbox, params: params).perform
    when 'evolution'
      Whatsapp::IncomingMessageEvolutionService.new(inbox: channel.inbox, params: params).perform
    when 'evolution_go'
      Whatsapp::IncomingMessageEvolutionGoService.new(inbox: channel.inbox, params: params).perform
    when 'notificame'
      Whatsapp::IncomingMessageNotificameService.new(inbox: channel.inbox, params: params).perform
    when 'zapi'
      Whatsapp::IncomingMessageZapiService.new(inbox: channel.inbox, params: params).perform
    when 'waha'
      Whatsapp::IncomingMessageWahaService.new(inbox: channel.inbox, params: params).perform
    else
      Whatsapp::IncomingMessageService.new(inbox: channel.inbox, params: params).perform
    end
  end
```

- [ ] **Step 4: Add WAHA session-based channel resolution**

In `try_find_channel_by_phone_number` (~line 487), add a branch keyed on `params[:session]`, placed before the generic `phone_number` fallback:

```ruby
    if params[:session].present?
      channel = find_channel_by_waha_session(params[:session])
      return channel if channel
    end
```

Add the resolver method next to `find_channel_by_evolution_go_instance`:

```ruby
  def find_channel_by_waha_session(session_name)
    Channel::Whatsapp.joins(:inbox)
                      .where(provider: 'waha')
                      .where("provider_config ->> 'session_name' = ?", session_name)
                      .first
  end
```

- [ ] **Step 5: Add `session.status` to the connection-lifecycle event list**

Find `CONNECTION_LIFECYCLE_EVENT_NAMES` (~line 620) and add `'session.status'`:

```ruby
  CONNECTION_LIFECYCLE_EVENT_NAMES = %w[
    Connected PairSuccess Disconnected ConnectFailure TemporaryBan LoggedOut
    connection.update
    session.status
  ].freeze
```

(Match the exact existing constant formatting/indentation in the file rather than retyping the whole array from scratch — this step only adds one line to it.)

- [ ] **Step 6: Run tests to verify they pass**

Run: `bundle exec rspec spec/jobs/webhooks/whatsapp_events_job_spec.rb`
Expected: PASS (new `waha dispatch` examples plus all pre-existing examples for other providers).

- [ ] **Step 7: Commit**

```bash
git add app/jobs/webhooks/whatsapp_events_job.rb spec/jobs/webhooks/whatsapp_events_job_spec.rb
git commit -m "feat(whatsapp): dispatch waha webhook events and resolve channel by session name"
```

---

## Task 7: `Api::V1::Waha` controllers — session create/start, QR code, disconnect

**Files:**
- Create: `evo-ai-crm-community/app/controllers/concerns/waha_concern.rb`
- Create: `evo-ai-crm-community/app/controllers/api/v1/waha/authorizations_controller.rb`
- Create: `evo-ai-crm-community/app/controllers/api/v1/waha/qrcodes_controller.rb`
- Modify: `evo-ai-crm-community/config/routes.rb`
- Test: `evo-ai-crm-community/spec/controllers/api/v1/waha/authorizations_controller_spec.rb`
- Test: `evo-ai-crm-community/spec/controllers/api/v1/waha/qrcodes_controller_spec.rb`

**Interfaces:**
- Produces: `POST /api/v1/accounts/:account_id/waha/authorization` (create session + start + register webhook), `GET /api/v1/accounts/:account_id/waha/qrcodes/:id` (fetch current QR), `DELETE /api/v1/accounts/:account_id/waha/authorization/logout` (disconnect, delegates to `WahaService#disconnect_channel_provider`).

- [ ] **Step 1: Add the routes**

In `config/routes.rb`, right after the `evolution_go` scope block (~line 521), add:

```ruby
      scope path: 'waha', as: 'waha' do
        resource :authorization, only: [:create], controller: 'waha/authorizations' do
          collection do
            delete :logout
          end
        end
        resources :qrcodes, only: [:show], controller: 'waha/qrcodes'
      end
```

- [ ] **Step 2: Write the failing controller tests**

Create `evo-ai-crm-community/spec/controllers/api/v1/waha/authorizations_controller_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Api::V1::Waha::AuthorizationsController, type: :controller do
  routes { Rails.application.routes }

  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  before { sign_in(admin) }

  describe 'POST #create' do
    it 'creates a channel with provider waha and the given config' do
      allow(HTTParty).to receive(:post).and_return(instance_double(HTTParty::Response, success?: true, code: 200, body: '{}', parsed_response: {}))
      allow(HTTParty).to receive(:get).and_return(instance_double(HTTParty::Response, success?: true, code: 200, body: '{}', parsed_response: {}))

      post :create, params: {
        account_id: account.id,
        authorization: { base_url: 'https://waha.example.com', api_key: 'key', session_name: 'default', phone_number: '+5511999999999' }
      }

      expect(response).to have_http_status(:success)
      expect(Channel::Whatsapp.find_by(phone_number: '+5511999999999').provider).to eq('waha')
    end
  end

  describe 'DELETE #logout' do
    it 'delegates to WahaService#disconnect_channel_provider' do
      channel = create(:channel_whatsapp, provider: 'waha', account: account, provider_config: { 'base_url' => 'https://waha.example.com', 'api_key' => 'key', 'session_name' => 'default' })
      expect_any_instance_of(Whatsapp::Providers::WahaService).to receive(:disconnect_channel_provider)

      delete :logout, params: { account_id: account.id, id: channel.inbox.id }

      expect(response).to have_http_status(:success)
    end
  end
end
```

Create `evo-ai-crm-community/spec/controllers/api/v1/waha/qrcodes_controller_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe Api::V1::Waha::QrcodesController, type: :controller do
  routes { Rails.application.routes }

  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:channel) { create(:channel_whatsapp, provider: 'waha', account: account, provider_config: { 'base_url' => 'https://waha.example.com', 'api_key' => 'key', 'session_name' => 'default' }) }

  before { sign_in(admin) }

  describe 'GET #show' do
    it 'returns the base64 QR code from WAHA' do
      response_double = instance_double(HTTParty::Response, success?: true, parsed_response: { 'value' => 'data:image/png;base64,AAA' })
      expect(HTTParty).to receive(:get).with(
        'https://waha.example.com/api/default/auth/qr',
        hash_including(query: { format: 'raw' })
      ).and_return(response_double)

      get :show, params: { account_id: account.id, id: channel.inbox.id }

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['qr_data_url']).to eq('data:image/png;base64,AAA')
    end
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bundle exec rspec spec/controllers/api/v1/waha/`
Expected: FAIL — controllers/concern/routes don't exist yet.

- [ ] **Step 4: Implement `WahaConcern`**

Create `evo-ai-crm-community/app/controllers/concerns/waha_concern.rb`:

```ruby
module WahaConcern
  extend ActiveSupport::Concern

  private

  def waha_webhook_url
    backend_url = ENV['BACKEND_URL'].presence || GlobalConfigService.load('BACKEND_URL', nil).to_s.strip.presence
    raise 'BACKEND_URL is not configured (required to register WAHA webhook callback)' if backend_url.blank?

    "#{backend_url.chomp('/')}/webhooks/whatsapp/waha"
  end

  def create_waha_session(base_url, api_key, session_name)
    HTTParty.post(
      "#{base_url.chomp('/')}/api/sessions",
      headers: { 'X-Api-Key' => api_key, 'Content-Type' => 'application/json' },
      body: {
        name: session_name,
        start: true,
        config: { webhooks: [{ url: waha_webhook_url, events: ['message', 'session.status'] }] }
      }.to_json,
      timeout: 30
    )
  end
end
```

- [ ] **Step 5: Implement `Api::V1::Waha::AuthorizationsController`**

Create `evo-ai-crm-community/app/controllers/api/v1/waha/authorizations_controller.rb`:

```ruby
class Api::V1::Waha::AuthorizationsController < Api::V1::BaseController
  include WahaConcern

  before_action :fetch_account
  before_action :check_authorization
  before_action :set_channel, only: [:logout]

  def create
    base_url = params.dig(:authorization, :base_url).to_s.strip
    api_key = params.dig(:authorization, :api_key).to_s.strip
    session_name = params.dig(:authorization, :session_name).to_s.strip
    phone_number = params.dig(:authorization, :phone_number).to_s.strip

    session_response = create_waha_session(base_url, api_key, session_name)
    unless session_response.success?
      render json: { error: "Failed to create WAHA session: #{session_response.code}" }, status: :unprocessable_entity
      return
    end

    channel = Current.account.channel_whatsapp.new(
      phone_number: phone_number,
      provider: 'waha',
      provider_config: { 'base_url' => base_url, 'api_key' => api_key, 'session_name' => session_name }
    )

    if channel.save
      ::Inbox.create!(account: Current.account, channel: channel, name: "WAHA #{phone_number}")
      render json: { id: channel.id, session_name: session_name }, status: :ok
    else
      render json: { error: channel.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def logout
    @channel.provider_service.disconnect_channel_provider
    head :ok
  end

  private

  def fetch_account
    @account = Current.account
  end

  def check_authorization
    authorize! :manage, :inboxes
  end

  def set_channel
    inbox = @account.inboxes.find(params[:id])
    @channel = inbox.channel
  end
end
```

- [ ] **Step 6: Implement `Api::V1::Waha::QrcodesController`**

Create `evo-ai-crm-community/app/controllers/api/v1/waha/qrcodes_controller.rb`:

```ruby
class Api::V1::Waha::QrcodesController < Api::V1::BaseController
  before_action :fetch_account
  before_action :check_authorization
  before_action :set_channel

  def show
    base_url = @channel.provider_config['base_url'].to_s.chomp('/')
    api_key = @channel.provider_config['api_key']
    session_name = @channel.provider_config['session_name']

    response = HTTParty.get(
      "#{base_url}/api/#{session_name}/auth/qr",
      headers: { 'X-Api-Key' => api_key },
      query: { format: 'raw' },
      timeout: 15
    )

    if response.success?
      render json: { qr_data_url: response.parsed_response['value'] }, status: :ok
    else
      render json: { error: "Failed to fetch QR code: #{response.code}" }, status: :unprocessable_entity
    end
  end

  private

  def fetch_account
    @account = Current.account
  end

  def check_authorization
    authorize! :manage, :inboxes
  end

  def set_channel
    inbox = @account.inboxes.find(params[:id])
    @channel = inbox.channel
  end
end
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bundle exec rspec spec/controllers/api/v1/waha/`
Expected: PASS. If `authorize!`/`Current.account`/`Api::V1::BaseController` conventions differ from what's shown (this plan mirrors the general Rails-controller-auth shape used elsewhere in this codebase but the exact `evolution_go/authorizations_controller.rb` before_actions were not fully reproduced here) — align `fetch_account`/`check_authorization`/`set_channel` with the exact before_action names already used in `app/controllers/api/v1/evolution_go/authorizations_controller.rb`, since that file is the authoritative pattern for this codebase's auth conventions in this controller family.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/concerns/waha_concern.rb app/controllers/api/v1/waha config/routes.rb spec/controllers/api/v1/waha
git commit -m "feat(whatsapp): add WAHA session create/QR/logout API endpoints"
```

---

## Task 8: Frontend types — WAHA payload and connection types

**Files:**
- Modify: `evo-ai-frontend-community/src/types/channels/inbox.ts`

**Interfaces:**
- Produces: `WhatsappWahaPayload`, `WahaConnectionParams`, `WahaAuthorizationResponse` types, added to the existing WhatsApp payload union.

- [ ] **Step 1: Add the types**

In `src/types/channels/inbox.ts`, alongside the existing `WhatsappEvolutionGoPayload` interface, add:

```ts
export interface WhatsappWahaPayload {
  provider: 'waha';
  phone_number: string;
  base_url: string;
  api_key: string;
  session_name: string;
}

export interface WahaConnectionParams {
  baseUrl: string;
  apiKey: string;
  sessionName: string;
  phoneNumber: string;
}

export interface WahaAuthorizationResponse {
  id: string;
  session_name: string;
}
```

Add `WhatsappWahaPayload` to the existing WhatsApp payload union type (find the union that already includes `WhatsappEvolutionGoPayload` and add `| WhatsappWahaPayload` to it).

- [ ] **Step 2: Type-check**

Run: `cd evo-ai-frontend-community && npx tsc --noEmit`
Expected: no new type errors introduced by this change (pre-existing unrelated errors, if any, are out of scope).

- [ ] **Step 3: Commit**

```bash
git add src/types/channels/inbox.ts
git commit -m "feat(whatsapp): add WAHA frontend payload/connection types"
```

---

## Task 9: Frontend `wahaService.ts`

**Files:**
- Create: `evo-ai-frontend-community/src/services/channels/wahaService.ts`
- Test: `evo-ai-frontend-community/src/services/channels/__tests__/wahaService.test.ts`

**Interfaces:**
- Consumes: `api` from `@/services/core/api`, `extractData` from `@/utils/apiHelpers`, types from task 8.
- Produces: `WahaService.verifyConnection(params: WahaConnectionParams): Promise<WahaAuthorizationResponse>`, `WahaService.getQRCode(inboxId: string)`, `WahaService.logout(inboxId: string)`.

- [ ] **Step 1: Write the failing test**

Create `evo-ai-frontend-community/src/services/channels/__tests__/wahaService.test.ts`:

```ts
import api from '@/services/core/api';
import WahaService from '../wahaService';

jest.mock('@/services/core/api');

describe('WahaService', () => {
  it('verifyConnection posts to /waha/authorization with the expected body', async () => {
    (api.post as jest.Mock).mockResolvedValue({ data: { id: '1', session_name: 'default' } });

    const result = await WahaService.verifyConnection({
      baseUrl: 'https://waha.example.com',
      apiKey: 'key',
      sessionName: 'default',
      phoneNumber: '+5511999999999',
    });

    expect(api.post).toHaveBeenCalledWith('/waha/authorization', {
      authorization: {
        base_url: 'https://waha.example.com',
        api_key: 'key',
        session_name: 'default',
        phone_number: '+5511999999999',
      },
    });
    expect(result).toEqual({ id: '1', session_name: 'default' });
  });

  it('getQRCode fetches the QR for an inbox', async () => {
    (api.get as jest.Mock).mockResolvedValue({ data: { qr_data_url: 'data:image/png;base64,AAA' } });

    const result = await WahaService.getQRCode('inbox-1');

    expect(api.get).toHaveBeenCalledWith('/waha/qrcodes/inbox-1');
    expect(result).toEqual({ qr_data_url: 'data:image/png;base64,AAA' });
  });

  it('logout deletes the session', async () => {
    (api.delete as jest.Mock).mockResolvedValue({ data: {} });

    await WahaService.logout('inbox-1');

    expect(api.delete).toHaveBeenCalledWith('/waha/authorization/logout', { params: { id: 'inbox-1' } });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd evo-ai-frontend-community && npx jest src/services/channels/__tests__/wahaService.test.ts`
Expected: FAIL — module `../wahaService` not found.

- [ ] **Step 3: Implement `wahaService.ts`**

Create `evo-ai-frontend-community/src/services/channels/wahaService.ts`:

```ts
import api from '@/services/core/api';
import { extractData } from '@/utils/apiHelpers';
import type { WahaConnectionParams, WahaAuthorizationResponse } from '@/types/channels/inbox';

const WahaService = {
  async verifyConnection(params: WahaConnectionParams): Promise<WahaAuthorizationResponse> {
    const requestData = {
      authorization: {
        base_url: params.baseUrl,
        api_key: params.apiKey,
        session_name: params.sessionName,
        phone_number: params.phoneNumber,
      },
    };
    const response = await api.post('/waha/authorization', requestData);
    return response.data as WahaAuthorizationResponse;
  },

  async getQRCode(inboxId: string) {
    const response = await api.get(`/waha/qrcodes/${inboxId}`);
    return extractData<any>(response);
  },

  async logout(inboxId: string) {
    const response = await api.delete('/waha/authorization/logout', { params: { id: inboxId } });
    return extractData<any>(response);
  },
};

export default WahaService;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd evo-ai-frontend-community && npx jest src/services/channels/__tests__/wahaService.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/services/channels/wahaService.ts src/services/channels/__tests__/wahaService.test.ts
git commit -m "feat(whatsapp): add frontend wahaService"
```

---

## Task 10: Frontend `WahaForm.tsx` + wire into the provider switch

**Files:**
- Create: `evo-ai-frontend-community/src/components/channels/forms/whatsapp/WahaForm.tsx`
- Modify: `evo-ai-frontend-community/src/components/channels/forms/whatsapp/index.tsx`

**Interfaces:**
- Consumes: same form-field conventions as `EvolutionGoForm.tsx` (`form`, `onFormChange` props, a `PhoneInput` for the phone number field).
- Produces: `<WahaForm form={form} onFormChange={onFormChange} hasWahaConfig={hasWahaConfig} />`, registered under `case 'waha':` in `WhatsappForms`.

- [ ] **Step 1: Implement `WahaForm.tsx`**

Create `evo-ai-frontend-community/src/components/channels/forms/whatsapp/WahaForm.tsx`, mirroring the field layout of `EvolutionGoForm.tsx` (base URL, API key hidden when `hasWahaConfig` is true, phone number via `PhoneInput`, session name):

```tsx
import { PhoneInput } from '@/components/ui/PhoneInput';
import { FormSection } from '@/components/ui/FormSection';

interface WahaFormProps {
  form: Record<string, any>;
  onFormChange: (field: string, value: any) => void;
  hasWahaConfig: boolean;
}

export const WahaForm = ({ form, onFormChange, hasWahaConfig }: WahaFormProps) => {
  return (
    <div className="space-y-4">
      <FormSection title="Connection">
        <label htmlFor="waha-base-url">Base URL</label>
        <input
          id="waha-base-url"
          type="text"
          value={form.base_url || ''}
          onChange={(e) => onFormChange('base_url', e.target.value)}
          placeholder="https://waha.example.com"
        />

        {!hasWahaConfig && (
          <>
            <label htmlFor="waha-api-key">API Key</label>
            <input
              id="waha-api-key"
              type="password"
              value={form.api_key || ''}
              onChange={(e) => onFormChange('api_key', e.target.value)}
            />
          </>
        )}

        <label htmlFor="waha-session-name">Session name</label>
        <input
          id="waha-session-name"
          type="text"
          value={form.session_name || ''}
          onChange={(e) => onFormChange('session_name', e.target.value)}
          placeholder="default"
        />

        <label htmlFor="waha-phone-number">Phone number</label>
        <PhoneInput
          id="waha-phone-number"
          value={form.phone_number || ''}
          onChange={(value) => onFormChange('phone_number', value)}
        />
      </FormSection>
    </div>
  );
};
```

(If `PhoneInput`/`FormSection` component prop names differ slightly from this sketch, match `EvolutionGoForm.tsx`'s actual imports exactly — that file is the authoritative reference for these two shared components' real API.)

- [ ] **Step 2: Wire into the provider switch**

In `src/components/channels/forms/whatsapp/index.tsx`, add the import and case:

```tsx
import { WahaForm } from './WahaForm';

// ...inside WhatsappFormsProps, add:
// hasWahaConfig: boolean;

export const WhatsappForms = ({ selectedProvider, form, onFormChange, hasEvolutionConfig, hasEvolutionGoConfig, hasWahaConfig, canFB, onCancel }: WhatsappFormsProps) => {
  switch (selectedProvider.id) {
    case 'whatsapp_cloud': return <CloudWhatsappForm form={form} onFormChange={onFormChange} canFB={canFB} onCancel={onCancel} />;
    case 'twilio': return <TwilioWhatsappForm form={form} onFormChange={onFormChange} />;
    case 'notificame': return <NotificameForm form={form} onFormChange={onFormChange} />;
    case 'zapi': return <ZapiForm form={form} onFormChange={onFormChange} />;
    case 'evolution': return <EvolutionForm form={form} onFormChange={onFormChange} hasEvolutionConfig={hasEvolutionConfig} />;
    case 'evolution_go': return <EvolutionGoForm form={form} onFormChange={onFormChange} hasEvolutionGoConfig={hasEvolutionGoConfig} />;
    case 'waha': return <WahaForm form={form} onFormChange={onFormChange} hasWahaConfig={hasWahaConfig} />;
    default: return <div>Provider not implemented</div>;
  }
};
```

Keep every other case exactly as it already is in the file — only add the import line and the new `case 'waha':` branch, and thread `hasWahaConfig` through the destructured props and the `WhatsappFormsProps` interface next to `hasEvolutionGoConfig`.

- [ ] **Step 3: Manual verification**

Run the frontend dev server (`npm run dev` in `evo-ai-frontend-community`), open the new-channel WhatsApp wizard, select the WAHA provider once task 11 registers it, and confirm the form renders without console errors.

- [ ] **Step 4: Commit**

```bash
git add src/components/channels/forms/whatsapp/WahaForm.tsx src/components/channels/forms/whatsapp/index.tsx
git commit -m "feat(whatsapp): add WahaForm and wire it into the provider form switch"
```

---

## Task 11: Register WAHA as a selectable provider (channel type list, icon, translations, form defaults, submission, validation)

**Files:**
- Modify: `evo-ai-frontend-community/src/constants/channelTypes.ts`
- Modify: `evo-ai-frontend-community/src/components/channels/ChannelIcon.tsx`
- Modify: `evo-ai-frontend-community/src/utils/channelUtils.ts`
- Modify: `evo-ai-frontend-community/src/hooks/channels/useChannelForm.ts`
- Modify: `evo-ai-frontend-community/src/hooks/channels/useChannelSubmission.ts`
- Modify: `evo-ai-frontend-community/src/hooks/channels/useChannelValidation.ts`
- Add asset: `evo-ai-frontend-community/src/assets/channels/waha.png`

**Interfaces:**
- Consumes: `WahaService` (task 9), `WhatsappWahaPayload` (task 8).
- Produces: WAHA appears as a selectable card in the WhatsApp provider list, with its own icon, translated label, connect/test-connection flow, and field validation, using the exact same integration points every other provider (e.g. `evolution_go`) already uses.

- [ ] **Step 1: Add the provider entry to `channelTypes.ts`**

In `src/constants/channelTypes.ts`, add to the `whatsapp` channel type's `providers` array, after the `evolution_go` entry:

```ts
  { id: 'waha', name: 'WAHA', description: 'Self-hosted WhatsApp HTTP API (WAHA)' },
```

- [ ] **Step 2: Add the icon**

Add a `waha.png` (or `.svg`) file under `src/assets/channels/` (use WAHA's public logo asset, matching the existing `evolution-go.png` convention). In `src/components/channels/ChannelIcon.tsx`, alongside the existing `iconEvolutionGo` import (~line 9):

```tsx
import iconWaha from '@/assets/channels/waha.png';
```

In `getChannelIconSrc`'s `whatsapp` branch (~lines 120-141), add:

```tsx
    if (prov === 'waha') return iconWaha;
```

- [ ] **Step 3: Add the translation**

In `src/utils/channelUtils.ts`, `PROVIDER_TRANSLATIONS` (~lines 77-87):

```ts
  waha: 'WAHA',
```

- [ ] **Step 4: Add form defaults in `useChannelForm.ts`**

In `handleProviderSelect`'s switch (~lines 67-225), add a case mirroring the `evolution_go` case:

```ts
      case 'waha':
        setForm((prev) => ({
          ...prev,
          base_url: '',
          api_key: '',
          session_name: '',
          phone_number: prev.phone_number || '',
        }));
        break;
```

Also expose `hasWahaConfig` alongside `hasEvolutionGoConfig` (~line 271):

```ts
    hasWahaConfig: config.hasWahaConfig === true,
```

This assumes `config` (from `GlobalConfigContext` or the equivalent integration-requirements source) will be extended with a `hasWahaConfig` flag server-side — if no such global default exists for WAHA (unlike Evolution Go, WAHA has no environment-level admin credentials to fall back to, since every WAHA channel supplies its own `base_url`/`api_key`), default this to `false` and skip hiding the API key field for WAHA entirely (i.e. `WahaForm` from task 10 can drop the `hasWahaConfig` conditional and always show the API key input). Confirm with the team whether a global WAHA default is wanted before implementing; if not, simplify task 10's form accordingly.

- [ ] **Step 5: Wire test-connection and submission in `useChannelSubmission.ts`**

In `testConnection` (~lines 172-225), add:

```ts
    } else if (selectedProvider.id === 'waha') {
      try {
        await WahaService.verifyConnection({
          baseUrl: form.base_url,
          apiKey: form.api_key,
          sessionName: form.session_name,
          phoneNumber: form.phone_number,
        });
        setConnectionStatus('success');
      } catch (error) {
        setConnectionStatus('error');
      }
```

In `submitCreate`'s `case 'whatsapp':` switch (~lines 636-713), add a branch building the `WhatsappWahaPayload` and calling `WahaService.verifyConnection`, following the same pending-instance-cleanup pattern used for `evolution_go` (lines 58-78, 741-756):

```ts
    } else if (selectedProvider.id === 'waha') {
      const payload: WhatsappWahaPayload = {
        provider: 'waha',
        phone_number: form.phone_number,
        base_url: form.base_url,
        api_key: form.api_key,
        session_name: form.session_name,
      };
      const result = await WahaService.verifyConnection({
        baseUrl: payload.base_url,
        apiKey: payload.api_key,
        sessionName: payload.session_name,
        phoneNumber: payload.phone_number,
      });
      pendingInstanceRef.current = { provider: 'waha', id: result.id };
```

Add the import at the top of the file: `import WahaService from '@/services/channels/wahaService';` and `import type { WhatsappWahaPayload } from '@/types/channels/inbox';`.

- [ ] **Step 6: Add validation in `useChannelValidation.ts`**

Mirror `validateEvolutionGo` (~lines 121-147):

```ts
function validateWaha(form: Record<string, any>, hasWahaConfig: boolean): string[] {
  const errors: string[] = [];
  if (!form.base_url) errors.push('Base URL is required');
  if (!hasWahaConfig && !form.api_key) errors.push('API key is required');
  if (!form.session_name) errors.push('Session name is required');
  if (!form.phone_number) errors.push('Phone number is required');
  return errors;
}
```

And add the case in `validateByChannelAndProvider`'s inner switch (~line 206):

```ts
    case 'waha':
      return validateWaha(form, hasWahaConfig);
```

- [ ] **Step 7: Manual verification**

Run the frontend dev server, open the WhatsApp new-channel wizard, confirm the WAHA card appears with its icon and label, selecting it shows `WahaForm`, filling in a (mock or real) WAHA base URL/API key/session name and clicking "Test connection" hits `POST /waha/authorization` (network tab), and validation errors show for empty required fields.

- [ ] **Step 8: Commit**

```bash
git add src/constants/channelTypes.ts src/components/channels/ChannelIcon.tsx src/assets/channels/waha.png src/utils/channelUtils.ts src/hooks/channels/useChannelForm.ts src/hooks/channels/useChannelSubmission.ts src/hooks/channels/useChannelValidation.ts
git commit -m "feat(whatsapp): register WAHA as a selectable provider in the channel creation wizard"
```

---

## Task 12: Optional `waha` service in `docker-compose.dokploy.yaml`

**Files:**
- Modify: `docker-compose.dokploy.yaml`

**Interfaces:**
- Produces: a `waha` service block for self-hosting WAHA alongside this stack (optional convenience — per the confirmed requirement, `provider_config.base_url` can already point at any externally-hosted WAHA instance without this).

- [ ] **Step 1: Add the service block**

Add, alongside the existing `evolution-api:` block:

```yaml
  # ---------------------------------------------------------------------------
  # WAHA (WhatsApp HTTP API) — optional, for self-hosting alongside this stack.
  # provider_config.base_url on a Channel::Whatsapp('waha') row does not have
  # to point here; this is a convenience service, not a requirement.
  # ---------------------------------------------------------------------------
  waha:
    image: devlikeapro/waha:latest
    pull_policy: always
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: "2.0"
          memory: 2G
        reservations:
          cpus: "0.5"
          memory: 512M
    expose:
      - "3000"
    volumes:
      - waha_sessions:/app/.sessions
    environment:
      WAHA_API_KEY: ${WAHA_API_KEY}
      WHATSAPP_HOOK_URL: ${BACKEND_URL}/webhooks/whatsapp/waha
      WHATSAPP_HOOK_EVENTS: "message,session.status"
```

Add `waha_sessions:` to the top-level `volumes:` section alongside `evolution_data:`.

Verify the exact env var names (`WAHA_API_KEY`, `WHATSAPP_HOOK_URL`, `WHATSAPP_HOOK_EVENTS`) against WAHA's own Docker docs before deploying — this plan's names are WAHA's documented convention as of the design pass but should be double-checked against the pinned image tag actually deployed.

- [ ] **Step 2: Manual verification**

`docker compose -f docker-compose.dokploy.yaml config` to confirm the YAML parses, then (in a non-production environment) `docker compose -f docker-compose.dokploy.yaml up waha` and confirm it starts and responds on its exposed port.

- [ ] **Step 3: Commit**

```bash
git add docker-compose.dokploy.yaml
git commit -m "feat(deploy): add optional waha service to docker-compose.dokploy.yaml"
```

---

## Task 13: Full regression pass

- [ ] **Step 1: Run the full WhatsApp-related backend spec suite**

Run: `cd evo-ai-crm-community && bundle exec rspec spec/models/channel/whatsapp_spec.rb spec/builders/contact_inbox_with_contact_builder_spec.rb spec/services/whatsapp spec/jobs/webhooks/whatsapp_events_job_spec.rb spec/controllers/api/v1/waha spec/requests/webhooks/whatsapp_waha_spec.rb`
Expected: PASS, 0 failures (matching the same "full regression, only pre-existing unrelated failures allowed" bar used when `6c8315b` was verified).

- [ ] **Step 2: Rubocop**

Run: `cd evo-ai-crm-community && bundle exec rubocop app/services/whatsapp app/models/channel/whatsapp.rb app/builders/contact_inbox_with_contact_builder.rb app/controllers/webhooks/whatsapp_controller.rb app/controllers/api/v1/waha app/controllers/concerns/waha_concern.rb app/jobs/webhooks/whatsapp_events_job.rb`
Expected: no new offenses.

- [ ] **Step 3: Frontend type-check and tests**

Run: `cd evo-ai-frontend-community && npx tsc --noEmit && npx jest src/services/channels src/hooks/channels src/components/channels`
Expected: PASS, no new type errors or test failures.

- [ ] **Step 4: Manual end-to-end verification against a real WAHA instance**

Using a real (or locally-run) WAHA container: create a WAHA channel through the CRM UI, scan the QR code, confirm the channel shows connected, send a text message from the CRM and confirm it arrives on WhatsApp, send a message from a WhatsApp phone to the connected number and confirm it appears in the CRM conversation with the correct contact (including a DDD ≥ 31 Brazilian number, to confirm the phone-normalization/smart-lookup fix from task 3 actually prevents a duplicate contact).

- [ ] **Step 5: Commit (if any fixups were needed)**

```bash
git add -A
git commit -m "fix(whatsapp): address regression/rubocop fixups for waha provider"
```
