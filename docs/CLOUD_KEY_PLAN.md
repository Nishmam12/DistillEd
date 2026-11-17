# Cloud AI with the user's own API key: implementation plan

Status: steps 1-5 and 7 built and unit-tested on 2026-11-15, not pushed. Step 6 (real keys on a device, against each preset) is still to do, and the Render OpenRouter and Exa keys still need revoking by hand. Written 2026-11-15.

## What changes and why

Today every cloud AI call goes from the app to our gateway on Render
(`server/ai-gateway`), which calls OpenRouter with the team's key. That service
is gone from Render (every path answers 404 with `x-render-routing: no-server`),
so Explain-in-cloud, Research, cloud page analysis and cloud figure reads are
all down.

Instead of reviving it, the app will call an AI provider directly with a key
the user adds in Settings. This is the only cloud path: no key, no cloud. The
on-device model is unaffected.

What we gain: no server to host, no bill, no abuse surface, and the user picks
the model. What we lose: zero-setup cloud, and web search in Research (it used
our Exa key through the gateway).

The HuggingFace token is a separate thing. It only unlocks gated on-device model
downloads and is not touched by this plan (see "Follow-ups").

## Design in one paragraph

One new class, `OpenAiCompatibleProvider`, speaks the OpenAI
`/chat/completions` format to a configurable base URL. OpenAI, OpenRouter,
Anthropic, Gemini, Groq, Mistral, DeepSeek, xAI and Together all expose that
format, so a provider is just a preset of base URL plus the user's key and a
model name. The class implements the same three interfaces
`CloudGatewayProvider` does (`AiProvider`, `ToolCallingClient`,
`ImageTranscriber`) and replaces it at the one place it is constructed. No
feature code changes.

Decisions already made:

- **One model, not two tiers.** The mid and frontier routes both use the
  user's one chosen model. Add a second model slot only if someone asks.
- **No hardcoded model names.** Model ids go stale. The model list comes from
  the provider's `GET /models`; a free-text field is the fallback.
- **The key goes from the device to the provider and nowhere else.** Stored in
  the platform keystore through the existing `SecretStore`.
- **No key means cloud is off.** It behaves exactly like the on-device mode, so
  every existing fallback applies.

## Steps

Each step leaves the app building and the tests passing.

### 1. Settings: store the provider, model and key

File: `lib/core/providers/settings_provider.dart`

- Add `cloudBaseUrl` and `cloudModel` (SharedPreferences) and `cloudApiKey`
  (keystore, key `ai.cloudApiKey`). Copy the `huggingFaceToken` pattern,
  including `sanitizeToken` and loading before `loaded` flips to true. There is
  no legacy plain-text copy to migrate.
- Add `hasCloudKey`: key, base URL and model are all non-empty.
- Change the `cloudAiEnabled` getter to `aiMode.allowsCloud && hasCloudKey`.
  Almost every cloud predicate already asks this getter, so this one line is
  what makes "no key" behave as "cloud off".
- In `lib/features/ai/presentation/ai_providers.dart`, `_mayUseCloud` and
  `mayAnalyzeInCloud` read `aiMode` directly. Make both go through
  `cloudAiEnabled` as well.

Test: copy `test/core/providers/settings_hugging_face_token_test.dart` for the
key, and add a case that `cloudAiEnabled` is false in `auto` mode with no key.

### 2. Presets

New file: `lib/features/ai/data/providers/cloud_presets.dart`

A const list of `(id, label, baseUrl, keyPageUrl)`. Base URLs (each answered an
auth error to a dummy-key probe on 2026-11-15):

| Preset | Base URL |
| --- | --- |
| OpenRouter | `https://openrouter.ai/api/v1` |
| Google Gemini | `https://generativelanguage.googleapis.com/v1beta/openai` |
| OpenAI | `https://api.openai.com/v1` |
| Anthropic | `https://api.anthropic.com/v1` |
| Groq | `https://api.groq.com/openai/v1` |
| Mistral | `https://api.mistral.ai/v1` |
| DeepSeek | `https://api.deepseek.com` |
| xAI | `https://api.x.ai/v1` |
| Together | `https://api.together.xyz/v1` |
| Custom | user types it |

For Custom, accept only `https://`, except for localhost and private addresses
(a local Ollama). The key is sent to whatever is typed here.

### 3. The provider

New file: `lib/features/ai/data/providers/openai_compatible_provider.dart`

Constructor takes base URL, key, model, `isCloudAllowed`, optional `Dio`. Start
from `cloud_gateway_provider.dart` and keep its `_requireCloudAllowed`, cancel
handling and timeouts. What differs:

- **Request.** `POST {baseUrl}/chat/completions`, header
  `Authorization: Bearer <key>`. Body: `model`, `messages` (system prompt first,
  then history, then the prompt), `stream: true`, `temperature`, `max_tokens`,
  and `tools` + `tool_choice: "auto"` when tools are given. History turns and
  `toolSchema()` output are already in OpenAI shape, so they pass through as is.
- **Stream.** Lines are `data: {json}`, ending with `data: [DONE]`. Text is
  `choices[0].delta.content`. An `error` object mid-stream becomes
  `AiGenerationException`.
- **Tool calls.** They arrive in fragments under `choices[0].delta.tool_calls`,
  keyed by `index`: `id` and `function.name` come once, `function.arguments`
  comes in pieces that must be joined before parsing. Emit one
  `ToolCallRequested` per call when the stream ends. The gateway did this in
  `server/ai-gateway/app/providers/gemma_cloud_provider.py`
  (`generate_with_tools`); port that loop, including the size limit on
  arguments and the "incomplete tool call" error.
- **Empty prompt on a tool hop.** When `prompt` is empty (the new turn is the
  tool result already in history), do not append an empty user message.
- **Images.** `transcribeImage` sends one non-streamed request whose user
  message content is a list: an `image_url` part holding
  `data:image/png;base64,...` and a `text` part with the prompt. Return
  `choices[0].message.content`. Keep the 90 s timeout.
- **Capabilities.** `modelId` is `cloud-<presetId>-<model>` (it is part of the
  read cache key, so changing model re-reads pages). `displayName` is the model
  name. `contextWindowTokens` is 32,000 unless the `/models` entry carries
  `context_length` (OpenRouter does). 32,000 is a deliberate floor: most
  current models allow more, and guessing high truncates silently.
- **Errors.** Extend `_mapError`:

  | Status | Message |
  | --- | --- |
  | 401, 403 | "Your AI API key was rejected. Check it in Settings." |
  | 402 | "Your AI provider account is out of credit." |
  | 404 | "The model '{model}' was not found at this provider." |
  | 429 | "Your AI provider is rate-limiting you. Try again shortly." |
  | timeouts, no connection | "AI provider unreachable" |

  All but 404 are `AiUnavailableException`, so local fallbacks still fire.
- **Never log the key.** Do not log request headers or pass a `DioException`
  with its `requestOptions` to `error_log.dart`.

Also add a `listModels()` helper: `GET {baseUrl}/models`, returning ids (and
`context_length` where present). The settings screen uses it both as the model
picker and as the key check.

Test: port `test/features/ai/data/providers/cloud_gateway_provider_test.dart`
to the new class, with new cases for fragmented tool calls, `[DONE]`, the image
body, and each error status.

### 4. Wire it in

File: `lib/features/ai/presentation/ai_providers.dart`

- Replace `cloudGatewayMidProvider` and `cloudGatewayFrontierProvider` with one
  `cloudAiProvider` that watches the three settings and builds an
  `OpenAiCompatibleProvider`. Rename the eleven or so call sites; pass the same
  instance for both `cloudMid` and `cloudFrontier` in `RoutedAiProvider`.
- Remove `WebSearchTool` from `toolsProvider`. Research keeps Calculator and
  Wikipedia. Delete `web_search_tool.dart` and its test, and drop `web_search`
  from Research's system prompt if it is named there.
- Remove `cloudGatewayBaseUrl`, and `loadDeviceKey()` from `lib/main.dart`.
- Delete `cloud_gateway_provider.dart` and its test.
- Grep for the strings `cloud-gateway`, `Cloud (Gemma)` and `gateway` in
  `lib/` (provenance labels, the first-cloud-call explainer, error text) and
  reword anything that tells the user their notes go to "Margo's cloud". They
  now go to the provider the user chose, and the confirmation should name it.

### 5. Settings screen

Files: `lib/features/settings/presentation/screens/ai_models_screen.dart`,
`settings_widgets.dart`, `settings_screen.dart`

- A "Cloud AI provider" row above the HuggingFace row, subtitle showing the
  provider and model, or "Add a key to use cloud AI".
- A dialog modelled on `_HuggingFaceTokenDialog`: preset dropdown, key field
  (obscured), a link to the preset's key page, then a model dropdown filled by
  `listModels()` once a key is entered. If `listModels()` fails with anything
  other than an auth error, fall back to a free-text model field. An auth error
  shows "key rejected" and does not save.
- Where the AI mode is chosen, show a hint when the mode allows cloud but no
  key is saved, since the mode will otherwise look like it does nothing.

### 6. Test on a device with real keys

Unit tests cannot prove provider compatibility. On the Pixel 7 Pro, with at
least OpenRouter, Gemini and one of OpenAI or Anthropic:

1. Explain streams text.
2. Research makes a Wikipedia tool call and answers from it.
3. A figure read returns parseable JSON from a vision model.
4. A wrong key, an empty-credit account and a made-up model name each give the
   right message, and the feature falls back on-device where it used to.
5. Leaving the sidebar mid-stream cancels cleanly.

Record which presets passed in `TEAM_CHANGELOG.md`.

### 7. Remove the gateway (approved 2026-11-15)

Delete `server/ai-gateway/`, `render.yaml` and the gateway sections of
`README.md`, `docs/HANDOVER.md` and `docs/SECURITY_REVIEW.md`. Do this as its
own commit so it can be reverted alone. Revoke the OpenRouter and Exa keys that
were set in the Render dashboard.

## Known risks

- **Parameter differences.** Some newer models reject `max_tokens` (they want
  `max_completion_tokens`) or a non-default `temperature`. If step 6 hits this,
  retry once without the offending field when the provider answers 400 naming
  it. Do not build this before it is seen.
- **Anthropic's endpoint is a compatibility layer**, not their main API. If
  streaming, tools or `/models` misbehave there, drop the preset or write a
  native adapter later.
- **Models without vision or tool calling.** A figure read or Research on such
  a model fails. Existing fallbacks cover figure reads; Research should say the
  chosen model does not support tools instead of a generic failure.
- **Prompt quality.** Prompts and JSON parsers were tuned on Gemma. Expect
  formatting differences on other models; fix prompts per finding in step 6.
- **Onboarding.** A student has to obtain a key. The dialog's key-page link is
  the whole onboarding for now.

## Follow-ups, not in this plan

- Web search with the user's own Exa (or other) key.
- Removing the HuggingFace token setting. Only the retired EmbeddingGemma 300M
  is gated; remove the setting once no install still needs to download it.
- A second, larger model for the frontier route.

## Before pushing

`flutter analyze`, the full test suite, `graphify update .`, a `CHANGELOG.md`
version entry, and a `TEAM_CHANGELOG.md` entry saying teammates must add their
own key to use cloud features.
