# Margo AI tutor: own-key models, model picker, teacher persona, tiers, conversation

Written 2026-11-16 by Fable 5.2 on branch `margo-device-fixes`, for a later
session (Opus) to build from without the author present.

**Status: saved for later. Not approved for building.** The user's words:
"write this up in a .md file, we will be touching on that later", then "create
a fully detailed plan so that … Opus can fully work on it."

Each part waits for its own go-ahead.

## Progress (updated 2026-11-17)

Branch **`ai-own-key-models`**, cut from `margo-device-fixes`. Not pushed, not
merged, not tested on a tablet.

| Part 1 step | State | Commit |
| --- | --- | --- |
| 1–2 Catalogue types, connection store | Done | `a8d21d0` |
| 3–4 OpenAI-compatible provider, tool calls | Done | `096e956` |
| 5–6 Key check, `resolveAnswerRoute`, consent rule | Done | `9f0e0d3` |
| 7 `SelectedAnswerProvider`, `CloudSendGate` | Done | `c9da08b` |
| 6 `answerModelId` setting (+ `setCloudPrivacy`) | Done | `502506e` |
| 7 Riverpod wiring (`ai_model_providers.dart`) | Done | `e0528b2` |
| 8 Ask, confirm dialog | Done | see `git log` |
| 8–9 Explain, quiz, flashcards | Done | see `git log` |
| 10 Summarize | Done | see `git log` |
| 11 Research | Done | see `git log` |
| 12 Key scrubbing in the error log | Done | `024d7ad` |
| 13 Settings section, add screen, picker, `/model` | **Not started** | |
| 14 Tablet check with a real key | **Not started** | |

`flutter analyze` clean. Full suite: 3,374 pass, 44 skipped, 1 failure, which is
the known flaky `test/core/error_log_test.dart` ("once past 100 KB…"); it passes
alone.

**Until step 13 exists there is no way to add a key or pick a model in the app.**
Everything is driven by `SettingsNotifier.setAnswerModelId` and
`userConnectionsProvider.notifier.save`, which only tests call today. With the
default `auto`, behaviour is what it was before this branch.

### Where the build differs from the design below

Read these before trusting sections 4.6–4.9; the code is the truth.

1. **Summarize asks from inside the service, not the notifier.**
   `summarizeScope` takes `confirmSend` and calls it only when a note is really
   about to be sent: after the page is read, the gate passes and the cache
   misses. A no throws `SummarizeCancelledException`, shown in the sheet as
   "Nothing was sent…".
2. **Explain and Research carry "does this need a yes" in data, not a callback
   on the notifier.** `CloudRouteDecision` gained `modelName`, `host` and
   `needsConfirm`. `ResearchNotifier` gained `needsConfirm` and `pickedModel`.
3. **`RoutedAiProvider.forcedCloud`** is how a pick overrides Explain's router.
4. **Quiz and flashcard notifiers take a plain `Future<bool> Function()
   confirmSend`**; `confirmAnswerSendProvider` supplies it.
5. **`CloudSendGate` has `needsConfirmation(model)` and `markConsented(model)`**
   so Explain's and Research's own confirm steps share its memory of what the
   student agreed to.
6. **The adapter adapts.** A 400 that names `max_tokens` is retried with
   `max_completion_tokens`, one that names `temperature` is retried without it,
   and the answer is remembered per connection. `ProviderPreset` therefore has
   no `maxTokensParam` or `sendsTemperature` fields.
7. **Web search is dropped from the tool list** while
   `margoCloudAvailableProvider` is false, for every route, not only a picked
   model.
8. **`AnswerTier.cloud`** exists and is not stored in Isar (checked).
9. The confirm dialog lives in `presentation/widgets/cloud_send_dialog.dart`
   and is started from `notebook_editor_screen.dart`'s `build`.

### Found while building (needs a decision; see section 10, items 11–13)

- **Nothing in the app can change `CloudPrivacy`.** There was no setter and
  there is no control, so every install has `askEachTime`. Consequences:
  `mayUploadImages` and `mayAnalyzeInCloud` are always false, so "cloud first"
  never actually reads a page in the cloud; and with a picked model, **every
  question will show the "send this?" dialog**. A setter now exists
  (`setCloudPrivacy`) but no screen calls it.
- A cached notebook summary shows no model badge even when a cloud model wrote
  it, because the cache returns with the default tier.

### The user's emphasis on RAG and depth (2026-11-16, when starting Part 1)

"Proper RAG is needed since we're sending the on-device data and questions to
the cloud or on-device AI, and the model needs to … think as an on-device
tutor, like an actual tutor who will explain the contents in detail or the
levels of detail the student is asking for. So the optimization and proper RAG
is needed."

What that means for the order of work:

- **Part 4c (retrieval quality) and Part 2 (teacher persona) are the user's
  priority after Part 1**, ahead of Part 3 (our tiers).
- Today a picked model with a large window still gets only `kRetrievalTopK = 5`
  passages and `NotesQa.answerOptions.maxTokens = 512`, and the Ask contract
  says "answer in a few clear sentences". A capable cloud model is therefore
  held to the on-device model's limits. Fixing that is small and belongs at the
  start of Part 4c: scale top-K and the reply cap to
  `provider.capabilities.contextWindowTokens`, and let the depth of an answer
  follow what the student asked for ("briefly", "in detail", "step by step")
  through the persona's style block in Part 2.

---

## 0. Start here (read before anything else)

1. Read `docs/HANDOVER.md` section 2 (standing rules) and `CLAUDE.md`. The rules
   that bite on this work:
   - Run `graphify query "<question>"` before reading or grepping code; a hook
     enforces it. Run `graphify update .` after changing code.
   - **Do not start a part unprompted.** Summarise what you will do and wait
     for a go-ahead, even on a bare "continue".
   - **Stop and ask** before any Isar schema change, any new dependency, any
     `git push`.
   - Isar enums are append-only. A schema change needs a migrator test.
   - Never add a `Co-Authored-By: Claude` trailer to commits in this repo.
   - Before any push: bump `pubspec.yaml` version, update `CHANGELOG.md`, and
     add a `TEAM_CHANGELOG.md` entry (see `CLAUDE.md`).
   - Installs and caches go on `G:` (`C:` is full).
   - Keep the user's email and project details out of requests to outside
     services.
   - End each part with: analyze clean, tests green, a summary, then stop.
2. Shell quirks on this machine (Windows, Git Bash): a bash heredoc containing
   an apostrophe fails; write commit messages to a file and use
   `git commit -F file`. `build_runner` reformats unrelated `.g.dart` files;
   revert those with `git checkout`.
3. **Re-verify section 2 of this file against the code.** It was true on
   2026-11-16. Roadmap steps 18–25 come first and will move things.
4. Re-check the gateway: `curl https://margo-ai-gateway.onrender.com/health`.
   On 2026-11-16 it returned 404 in 0.7 s, meaning no service on that host.
5. Read section 9 (things not verified) before trusting any detail marked
   "verify".
6. Model for the work: the user said Opus will do the coding. `HANDOVER.md`
   section 5 allows Sonnet for work "contained to a few files with a clear
   acceptance check". Section 11 says which pieces need the strongest model.

---

## 1. What the user asked for

In the user's words, condensed:

- "Establish an API route for the app's Cloud AI model, where user can put in
  their own APIs, and any model request will go through that API token rather
  than ours."
- "We will set a default Cloud AI for our app along with the local one, the
  Gemma model, and there will be a budget Cloud, there will be a free use Cloud
  model as well as premium, paid or multiple paid Cloud AI from our end."
- "If anyone wanna use more other AIs, they can put into their APIs with the
  AI's name, and it will get listed on the Cloud's list. Like they can switch
  between which AI they are preferring to use while using the app."
- "All of the Cloud requests and the local AI should treat the user as a
  student, and it should act as a teacher or a learning partner."
- "RAG and other stuff needs to be done properly."
- "A proper robust AI implementation inside the app, not just a wrapper … a
  full-fledged teaching assistant, like a NotebookLM concept."
- "Consider the efficiency and latency … for the AI to act smoothly."

### Decisions the user made on 2026-11-16

| Question | Answer |
| --- | --- |
| Premium models from us | **Shown locked.** Billing is a later project. |
| Free cloud tier funding | **Provider free quota now; soon a paid budget with hard caps, "like per user 5 request per day or 10".** |
| When to start | **After the polish roadmap (steps 18–25).** |

### Calls the author made (the user saw these and did not object; confirm before building)

1. Own-key requests go **from the device straight to the provider**. The key
   lives in the Android keystore and never reaches our server.
2. One **OpenAI-compatible** adapter first. Native adapters later.
3. Default teaching style is **explain, then check understanding**. A
   hints-first "Guide me" style is a switch.
4. The model picker is a **new "answer model" setting**, separate from
   `AiProcessingMode`.
5. **A user's key is spent only when they pick that model, or tap to use it.**
   Background work stays on-device. This is the one place the plan departs from
   "any model request will go through that API token", and the picker must say
   so in one line.
6. Page and figure reading (vision) **does not follow the picker**.

---

## 2. How the AI stack works today (verified by reading the files named)

### 2.1 The pieces

| Piece | Where | Facts |
| --- | --- | --- |
| Provider contract | `lib/features/ai/domain/ai_provider.dart` | `Stream<String> generate({prompt, systemPrompt, history, options})` and `AiCapabilities get capabilities`. `history` is already in the contract. |
| Capabilities | `domain/ai_capabilities.dart` | `modelId`, `displayName`, `contextWindowTokens`, `isLocal`. No tools or vision flags. |
| Errors | `domain/ai_exception.dart` | Sealed: `AiModelNotReadyException`, `AiUnavailableException`, `AiGenerationException`. Notifiers match on these. |
| On-device model | `data/providers/local_gemma_provider.dart` | Gemma 4 E2B. Window 4,096 tokens, 2,048 on low-RAM devices (`LlmModelSpec.liteMaxTokens`). One mutex for text and vision. Replays `history` with `session.addTurn`. No tool calling. Compacts the system prompt itself with `compactForWindow`. |
| Cloud | `data/providers/cloud_gateway_provider.dart` | `CloudGatewayProvider implements AiProvider, ToolCallingClient, ImageTranscriber`. Posts to `/v1/generate` with `model_tier`, reads SSE `data: {"text"}` / `{"tool_call"}` / `{"error"}`. Uses `gatewayDio`, which pins the gateway certificate and trusts **no** roots when a pin is set. |
| Gateway server | `server/ai-gateway/` (FastAPI) | `/v1/generate`, `/v1/vision`, `/v1/tools/search`, `/health`. `select_provider(model_tier, provider_hint)`: Gemma via OpenRouter by default, optional Gemini / Claude / GPT adapters chosen by `provider_hint`, which **the app never sends**. `providers/base.py` says the frontier adapters are "untested against a live key". Rate limit: SQLite table `usage(device_key, day)`, caps from env. `render.yaml` deploys it on Render's free plan. **Not live on 2026-11-16.** |
| Wiring | `presentation/ai_providers.dart` (888 lines) and its part `ai_rag_providers.dart` | Riverpod. `localAiProvider`, `cloudGatewayMidProvider`, `cloudGatewayFrontierProvider`, `_mayUseCloud(ref)` (the transport floor), `intelligentRouterProvider`, one provider per feature. |
| Settings | `lib/core/providers/settings_provider.dart` | `AiProcessingMode { onDevice, auto, cloudFirst }` stored as `ai.mode`; `allowsCloud` and `prefersCloud` getters. `CloudPrivacy { localOnly, askEachTime, allowCloudForNonSensitive }`. `cloudAiEnabled` is a derived getter. `setCloudAiEnabled(bool)` writes `auto` or `onDevice`. `hasSeenFirstCloudCall`. |
| Secrets | `lib/core/providers/secret_store.dart` | `SecretStore { read, write }`; `write(key, '')` deletes. `KeystoreSecretStore` (flutter_secure_storage) and `InMemorySecretStore` for tests. `secretStoreProvider` exists. Used for the HuggingFace token. |
| Voice | `domain/tutor_voice.dart` | `kTutorVoice`, `kMathMarkup`, compact twins, `compactForWindow(prompt, windowTokens)` which works by **`replaceAll` on the exact constant text** when the window is 2,048 or less. |
| Budgets | `domain/ai_router.dart`, `domain/text_budget.dart` | `AiRouter.inputWordBudgetFor(capabilities, systemPrompt:)` = window − 512 reply − 200 scaffolding − system prompt cost (3.5 chars/token), in words at 1.35 tokens/word. |
| RAG | `domain/rag/` | On-device EmbeddingGemma, Isar brute-force cosine, keyword search over page text, merged by reciprocal rank fusion. `kRetrievalTopK = 5`. `kMinRelevance = 0.45`, marked PROVISIONAL in the code. Scopes: page, imported PDF, notebook. Keyword half works before the embedding model is downloaded. |
| Learner data | `data/memory/learning_memory_repository.dart` | `allConcepts`, `weakConcepts(notebookId)`, `dueForReview`, `loadPreferences()` → `LearningPreferences { preferredExplainMode, preferredDifficulty, averageReviewsToMastery }`. **Recorded but never fed into any prompt.** |
| Quality guard | `domain/quality/ai_quality_guard.dart` | `run()` generates on `_local`, checks with `checkOutputQuality`, and re-runs on `_cloud` only when cloud is on, privacy is `allow` and the device is online. Under `askEachTime` it returns `canRetryOnCloud` for a button. `AnswerTier { local, cloudVerified, localLowConfidence }`. |
| Backup | `lib/data/backup/` | `.margo` exports notebook snapshots. It does not export SharedPreferences. `allowBackup="false"` in the manifest. |

### 2.2 Who answers today, feature by feature

**The on-device model answers almost everything, whatever the mode.** This is
why a model picker needs new routing and not just a new provider.

| Feature | Class | Wired to | Cloud today |
| --- | --- | --- | --- |
| Ask your notes | `NotesQa` + `AskNotesNotifier` | `localAiProvider` via `AiQualityGuard` | Only a re-run of a failed answer. Single-shot: **no `history` passed**. |
| Explain | `Explainer` + `ExplainNotifier` | `RoutedAiProvider` (`explainAiProviderProvider`) | Only when the text overflows the local window or the local model is on CPU. `ExplainNotifier` shows `ExplainConfirmCloud` **every time** a cloud route is chosen, whatever the privacy setting. |
| Summarize | `SummarizationService` (`lib/features/summarize/`) | `localAiProvider`, `AiRouter`, guard | Cloud slot is `CloudLlmClient`, a **different, non-streaming interface** whose only implementation is `StubCloudLlmClient`, which always throws. Stub on purpose: Summarize has no per-call confirmation. Checks "is the local model installed" before running. |
| Quiz | `QuizGenerator` + `QuizNotifier` | `localAiProvider` | None. JSON output, `temperature 0`, one retry with `_retryNudge`. |
| Flashcards | `FlashcardGenerator` + `FlashcardNotifier` | `localAiProvider` | None. Same shape as quiz. |
| Writing suggestions | `WritingAssistant` | `localAiProvider` | None. Runs on the page-analysis debounce, in the background. |
| Research | `Researcher` + `ResearchNotifier` | `cloudGatewayMidProvider` as `ToolCallingClient` | Cloud only. Owns the tool loop, `maxToolHops = 3`. Tools: calculator, Wikipedia, web search (web search calls the gateway). |
| Page analysis | `ContextEngine` | local, or `cloudGatewayMidProvider` when `mayAnalyzeInCloud` | Background. Follows `aiMode.prefersCloud` + privacy `allow`. |
| Page and figure reading | `routedImageTranscriberProvider`, `figureAnalyzerProvider`, `FigureQa` | local, or gateway vision | Follows `aiMode.prefersCloud` + `mayUploadImages`. |

### 2.3 Where `prefersCloud` is read (do not disturb these in Part 1)

`ai_providers.dart`: `localModelWarmerProvider`, `routedImageTranscriberProvider`,
`figureAnalyzerProvider`, `pageContentExtractorProvider` (`localIsSlow`, `lite`,
`readModelId`), `mayAnalyzeInCloud`. `ai_rag_providers.dart`: `figureQaProvider`.
`notebook_editor_screen.dart` near line 1425: passes
`preferCloud: settings.aiMode.prefersCloud` into `SummarizeRequest`.

`readModelId` is part of the read-cache key. Changing which model it names
makes every page be read again.

### 2.4 Where the teacher voice is and is not

| Uses `kTutorVoice` | Does not |
| --- | --- |
| `Explainer._base`, `NotesQa.systemPrompt`, `SummarizationService._voice`, `ContextEngine` | `Researcher.systemPrompt` ("You are a research assistant inside a note-taking app"), `QuizGenerator`, `FlashcardGenerator`, `WritingAssistant`, `FigureQa` |

---

## 3. Approach

| Approach | Trade-off | Verdict |
| --- | --- | --- |
| A. Send own-key requests through our gateway | Server adapters exist. But we would hold users' keys, the gateway is down and its free host sleeps (30–60 s wake), and every request costs us. | Rejected |
| B. Device → provider directly, one OpenAI-compatible adapter, catalogue and picker in the app | No key custody, one hop fewer, works with our gateway down. Tool-call parsing must be written in Dart. | **Chosen** |
| C. One SDK per provider in the app | Best per-provider features. Many new dependencies for a three-person, Android-only team. | Rejected for now |

Why B is safe: the common advice "never put API keys in a mobile app" is about a
developer's key shipped inside the app. Here the key belongs to the user and is
typed in by them, so keeping it only in the device keystore is the least
exposure available.

### The five parts

| Part | What | Schema change | New dependency | Detail level here |
| --- | --- | --- | --- | --- |
| 1 | Model catalogue, own keys, picker, routing | no | no | Full, build order included |
| 2 | Teacher persona for every feature | no | no | Full, draft text included |
| 3 | Our free / budget / premium tiers | no (server DB only) | no | Full on design, hosting is an open decision |
| 4 | Tutor conversation and retrieval | **yes, for saved chats; ask first** | no | Design sketch; needs its own short design session |
| 5 | Speed and efficiency | no | no | Checklist with targets |

Each part ends with analyze clean, tests green, a summary, and a stop.

---

## 4. Part 1: model catalogue, own keys, picker, routing

### 4.1 New files

```
lib/features/ai/domain/catalog/
  ai_model_entry.dart          AiModelEntry, ModelSource, MargoTier
  user_connection.dart         UserConnection (+ JSON)
  provider_preset.dart         ProviderPreset const table
  answer_route.dart            AnswerRoute, resolveAnswerRoute
  cloud_consent.dart           needsSendConfirmation
lib/features/ai/data/catalog/
  user_connection_store.dart   prefs JSON + SecretStore
  margo_catalog.dart           bundled list of our models (all unavailable until Part 3)
lib/features/ai/data/providers/
  openai_compatible_provider.dart
  model_connection_tester.dart
lib/features/ai/domain/routing/
  selected_answer_provider.dart
lib/features/ai/presentation/
  ai_model_providers.dart      `part of 'ai_providers.dart'` (same pattern as ai_rag_providers.dart)
  cloud_send_gate.dart         CloudSendGate notifier + the dialog listener
  widgets/model_picker_sheet.dart
lib/features/settings/presentation/screens/
  settings_cloud_models.dart   the "Cloud models" section
  add_connection_screen.dart   route /settings/models/add
```

### 4.2 Types

```dart
enum ModelSource { onDevice, margo, userKey }
enum MargoTier { free, budget, premium }

const String kAnswerAuto = 'auto';
const String kAnswerLocal = 'local';

@immutable
class AiModelEntry {
  final String id;               // 'margo:<id>' or 'user:<connectionId>:<modelId>'
  final String displayName;      // the name the user gave it, or ours
  final ModelSource source;
  final MargoTier? tier;         // margo only
  final int contextWindowTokens;
  final bool supportsTools;
  final bool supportsVision;     // recorded now, unused until vision follows a setting
  final bool locked;             // premium not purchasable yet
  final bool available;          // false = listed but cannot be picked
  final String? host;            // shown in consent copy; null on-device
}

class UserConnection {
  final String id;               // random, generated on add
  final String label;            // "the AI's name" the user types
  final String presetId;         // key into ProviderPreset.all, or 'custom'
  final String baseUrl;          // https only in Part 1
  final List<UserModel> models;  // the ones the user ticked
  final bool consentShown;       // first-use notice already seen
}
class UserModel {
  final String modelId;          // the provider's own id, sent on the wire
  final String displayName;
  final int contextWindowTokens;
  final bool supportsTools;
}

class ProviderPreset {
  final String id, name, baseUrl;
  final String maxTokensParam;   // 'max_tokens' or 'max_completion_tokens' — VERIFY per provider
  final bool sendsTemperature;   // some reasoning models reject it — VERIFY
  final int defaultContextWindow;
}
```

`ProviderPreset.all`: every base URL, limit and flag in it must be checked
against the provider's own documentation when written. Candidates seen during
planning, all from third-party pages:

| Provider | Base URL seen (verify) |
| --- | --- |
| OpenRouter | `https://openrouter.ai/api/v1` |
| Groq | `https://api.groq.com/openai/v1` |
| Mistral | `https://api.mistral.ai/v1` |
| DeepSeek | `https://api.deepseek.com` |
| xAI | `https://api.x.ai/v1` |
| Google Gemini (compatibility layer, reported as beta) | `https://generativelanguage.googleapis.com/v1beta/openai/` |
| OpenAI | `https://api.openai.com/v1` |
| Anthropic | **Do not add from memory.** Load the `claude-api` skill first and follow what it says about the compatibility endpoint and whether it is meant for production. |
| Custom | user types the URL |

An unknown model gets **8,000 tokens** as its window, editable under Advanced.
`contextWindowTokens` feeds `NotesQa.fitToBudget` and every
`AiRouter.inputWordBudgetFor` call, so it must never be guessed high.

### 4.3 Storage (no Isar change)

| What | Where | Key |
| --- | --- | --- |
| Connection metadata (list, JSON) | SharedPreferences | `ai.userConnections` |
| Each API key | `SecretStore` | `ai.userKey.<connectionId>` |
| Answer model choice | SharedPreferences, in `SettingsState` | `ai.answerModelId` (`auto` default) |

- `UserConnectionStore` takes a `SecretStore` (inject `InMemorySecretStore` in
  tests). `delete(connectionId)` removes the key in the same call.
- If the keystore write fails, tell the user and do not save the connection
  (the HuggingFace path keeps a session-only token; a connection with no key
  is useless).
- If the picked model's connection is deleted, the choice falls back to
  `auto` (see rule 6 in 4.5).

### 4.4 The OpenAI-compatible adapter

```dart
class OpenAiCompatibleProvider implements AiProvider, ToolCallingClient {
  OpenAiCompatibleProvider({
    required String baseUrl,
    required String modelId,
    required String displayName,
    required int contextWindowTokens,
    required Future<String?> Function() apiKey,   // read from SecretStore at call time
    required bool Function() isCloudAllowed,      // _mayUseCloud
    String maxTokensParam = 'max_tokens',
    bool sendsTemperature = true,
    Dio? dio,                                     // tests inject a fake adapter
  });
}
```

**Request** (`POST {baseUrl}/chat/completions`, header
`Authorization: Bearer <key>`, never a key in the URL):

```json
{
  "model": "<modelId>",
  "stream": true,
  "messages": [
    {"role": "system", "content": "<systemPrompt>"},
    {"role": "user", "content": "…"},
    {"role": "assistant", "content": "…", "tool_calls": [ … ]},
    {"role": "tool", "tool_call_id": "…", "content": "…"},
    {"role": "user", "content": "<prompt>"}
  ],
  "temperature": 0.2,
  "max_tokens": 512,
  "tools": [ {"type":"function","function":{"name":"…","description":"…","parameters":{…}}} ],
  "tool_choice": "auto"
}
```

- `AiMessage.toolCalls` is already stored in this OpenAI shape by `Researcher`,
  and `toolSchema(tool)` in `domain/tools/tool.dart` already builds the `tools`
  entries.
- On a tool hop after the first, `prompt` is `''`: **do not append an empty
  user turn** (same rule as `gemma_cloud_provider.py`).
- Omit `tools` and `tool_choice` when there are no tools. Omit `temperature`
  when the preset says so.

**Response:** lines of `data: {json}`. Ignore blank lines and lines that do not
start with `data: ` (some providers send `:` keep-alive comments). Stop at
`data: [DONE]`.

```json
{"choices":[{"delta":{"content":"text"}}]}
{"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"calculator","arguments":"{\"ex"}}]}}]}
{"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"pression\":\"2+2\"}"}}]}}]}
```

- Tool calls arrive in fragments keyed by `index`. `id` and `function.name`
  come on the first fragment only; `arguments` strings must be concatenated and
  parsed once the stream ends. Port the logic and the size bound from
  `server/ai-gateway/app/providers/gemma_cloud_provider.py`
  (`generate_with_tools`): incomplete or unparseable call → `AiGenerationException`.
- Emit `ToolTextChunk` for content and one `ToolCallRequested` per call at the end.
- A chunk with an empty `choices` list (usage-only chunk) is skipped.

**Transport rules**

- Its own `Dio` with the platform's normal trusted roots. **Never `gatewayDio`.**
- One `Dio` per connection, kept alive (connection reuse; see Part 5).
- Timeouts: connect 15 s; receive 60 s between chunks.
- A `CancelToken` cancelled in the stream's `finally`, as `CloudGatewayProvider`
  does, so leaving the screen stops the request.
- `isCloudAllowed()` is checked before every request and throws
  `AiUnavailableException('Cloud AI is turned off in Settings, so nothing was sent.')`.
- A missing key throws `AiUnavailableException('This model has no saved key. Add it again in Settings.')`.
- Https only. Reject `http://` in the add screen. Local-network servers
  (Ollama, LM Studio) need Android cleartext rules and are out of scope here.

**Error mapping**

| Condition | Exception and message |
| --- | --- |
| Connection error, any timeout | `AiUnavailableException("Couldn't reach <host>.")` |
| 401, 403 | `AiUnavailableException('<label> rejected the key. Check it in Settings.')` |
| 402 | `AiUnavailableException('Your <label> account is out of credit.')` |
| 404 | `AiGenerationException('<label> has no model called <modelId>.')` |
| 429 | `AiUnavailableException("<label>'s limit was reached. Try again in a moment.")` |
| Other status | `AiGenerationException('Request failed (HTTP <status>).')` |
| Malformed JSON line | `AiGenerationException('Malformed response from <label>.')` |

Never put Dio's own message, a header or the request body in an exception
message: `ErrorLog.record` writes `error.toString()` to a file the user can
share.

### 4.5 The answer route (the one function that decides)

```dart
sealed class AnswerRoute { const AnswerRoute(); }
class LocalOnly extends AnswerRoute { const LocalOnly(); }
class LocalFirst extends AnswerRoute {            // today's behaviour
  final AiModelEntry? escalation;                 // our model, or null
  const LocalFirst(this.escalation);
}
class CloudDirect extends AnswerRoute {
  final AiModelEntry model;
  const CloudDirect(this.model);
}

AnswerRoute resolveAnswerRoute({
  required AiProcessingMode aiMode,
  required CloudPrivacy privacy,
  required String answerModelId,
  required List<AiModelEntry> catalogue,
});
```

Rules, in order:

1. `aiMode == onDevice` → `LocalOnly`.
2. `privacy == localOnly` → `LocalOnly`.
3. `answerModelId == 'local'` → `LocalOnly`.
4. `answerModelId == 'auto'` → `LocalFirst(first margo entry that is available and not locked, else null)`.
5. The id names an entry that is available and not locked → `CloudDirect(entry)`.
6. The id names nothing usable (connection deleted, catalogue changed, locked) →
   same as rule 4, and the picker shows "that model is no longer available" once.

`aiMode` stays the master switch and keeps all its `prefersCloud` sites
untouched. Picking a cloud model while `aiMode == onDevice` asks "Cloud AI is
off. Turn it on?" and on yes calls `setAiMode(AiProcessingMode.auto)`, **never
`cloudFirst`**. `answerModelId` default `auto` reproduces today's behaviour
exactly, so existing users see no change.

### 4.6 Consent (once per user action, not once per model call)

```dart
bool needsSendConfirmation({
  required CloudPrivacy privacy,
  required bool firstEverCloudCall,       // !settings.hasSeenFirstCloudCall
  required bool firstUseOfConnection,     // !connection.consentShown
}) => privacy == CloudPrivacy.askEachTime || firstEverCloudCall || firstUseOfConnection;
```

```dart
class CloudSendPrompt { final String modelName; final String host; final bool longForm; }

class CloudSendGate extends StateNotifier<CloudSendPrompt?> {
  /// True at once when no confirmation is needed. Otherwise shows the prompt
  /// and completes with the user's answer. One prompt at a time: a second
  /// request while one is showing is declined. No answer in 60 s is a decline.
  Future<bool> confirm(AiModelEntry model);
  void answer(bool allow);
}
```

- One listener in the editor screen shows a dialog when the state is non-null.
  Every feature that can start a `CloudDirect` call is launched from the editor
  (sidebar, summary sheet, quiz sheet, flashcard sheet). Confirm that is still
  true when building.
- Copy (plain, names the third party): "Send this to **<model name>**? Text
  from your notes will go to **<host>** under your own account." First use adds
  one sentence on what leaves the device and that it can be turned off.
- On allow: mark `hasSeenFirstCloudCall` and the connection's `consentShown`.
- **The gate is called by the notifier, once, at the start of a user action.**
  It must not sit inside `AiProvider.generate`: Summarize's chunk-and-reduce and
  the quiz retry make several model calls per action and would prompt each time.

### 4.7 `SelectedAnswerProvider`

```dart
/// An AiProvider that answers with whatever the picker says, decided at call
/// time so a switch takes effect on the next question.
class SelectedAnswerProvider implements AiProvider {
  SelectedAnswerProvider({
    required AiProvider local,
    required AnswerRoute Function() route,
    required AiProvider Function(AiModelEntry) cloudFor,
  });
  @override AiCapabilities get capabilities => switch (route()) {
        CloudDirect(:final model) => cloudFor(model).capabilities,
        _ => local.capabilities,
      };
  @override Stream<String> generate({...}) => switch (route()) {
        CloudDirect(:final model) => cloudFor(model).generate(...),
        _ => local.generate(...),
      };
}
```

- `capabilities` being dynamic matters: `NotesQa.fitToBudget`,
  `QuizGenerator` and `FlashcardGenerator` all budget from
  `_provider.capabilities`.
- A cloud failure under `CloudDirect` **propagates**. It never falls back to
  the on-device model silently, and never to a different cloud provider. The
  error message ends with "Switch to On-device in the model picker to answer
  without the network."

### 4.8 Routing table (Part 1's acceptance check)

| Feature | On-device picked | Auto (default, as today) | A cloud model picked |
| --- | --- | --- | --- |
| Ask your notes | on-device | on-device; a failed answer may re-run on **our** cloud model | **the picked model**; the search over notes stays on-device |
| Explain | on-device | on-device if it fits, else our cloud model | the picked model |
| Summarize | on-device | as today | the picked model, behind the gate |
| Quiz, flashcards | on-device | on-device | the picked model |
| Research (tools) | unavailable, as today | our cloud model | the picked model if `supportsTools`, else "this model can't use tools" |
| Writing suggestions (background) | on-device | on-device | **on-device** |
| Page analysis (background) | on-device | follows `aiMode`, as today | **follows `aiMode`, not the picker** |
| Page and figure reading | on-device | follows `aiMode`, as today | **follows `aiMode`, not the picker** |

While the gateway is down "our cloud model" resolves to nothing: Auto behaves
as it does today with the gateway unreachable, our catalogue entries show as
"coming soon" (`available: false`), and web search is left out of Research's
tool list (calculator and Wikipedia remain).

### 4.9 Changes to existing files, feature by feature

**`settings_provider.dart`**
- Add `answerModelId` to `SettingsState` (+ `copyWith`), key `ai.answerModelId`,
  restore with default `auto`, and `Future<void> setAnswerModelId(String id)`.
- No change to `aiMode`, `cloudPrivacy`, `setCloudAiEnabled`.

**`ai_providers.dart` + new part `ai_model_providers.dart`**
- `userConnectionsProvider` (StateNotifier over `UserConnectionStore`).
- `modelCatalogueProvider` → `List<AiModelEntry>`: the bundled margo entries
  (all `available: false` until Part 3) + one entry per ticked user model.
- `answerRouteProvider` → `AnswerRoute Function()` reading settings and the
  catalogue at call time.
- `userModelProviderFamily(entryId)` → a cached `OpenAiCompatibleProvider`
  (so its `Dio` is reused).
- `answerAiProvider` → the `SelectedAnswerProvider`.
- `cloudSendGateProvider`.
- `activeToolsClientProvider` → `ToolCallingClient? Function()`: the picked
  model if `supportsTools`; else `cloudGatewayMidProvider` once our tier is
  available; else null.
- `toolsProvider`: include `WebSearchTool` only when our tier is available.

**Ask** (`ai_rag_providers.dart`, `ask_notes_notifier.dart`)
- `notesQaProvider`: `provider: ref.watch(answerAiProvider)`.
- `AskNotesNotifier` gets `AnswerRoute Function() route` and
  `Future<bool> Function(AiModelEntry) confirmSend`.
- In `ask()`, after sources are found and before `_generate`: if the route is
  `CloudDirect`, await the gate; on decline set `AskNotesComposing` and return.
- In `_generate`: when the route is `CloudDirect`, **skip the guard** and stream
  from `_qa.answer(...)` (this mirrors what `ExplainNotifier._generate` already
  does with `fromCloud`). Return `GuardedResult(tier: AnswerTier.cloud)`.
- `AiQualityGuard` itself is unchanged in Part 1.

**`AnswerTier`**
- Append `cloud` ("the picked cloud model answered"). Fix the exhaustive
  switches the compiler points at, including
  `presentation/widgets/answer_tier_banner.dart`, which should show a chip with
  the model's name. First confirm `AnswerTier` is not stored in Isar (see 9).
- `AskNotesAnswered`, `ExplainReady` and `SummarizationResult` need the model's
  display name for that chip; add an optional `modelName` field to each.

**Explain** (`intelligent_router.dart`, `explain_notifier.dart`, wiring)
- `RoutedAiProvider`: add `AiProvider? Function()? forcedCloud`. When it returns
  a provider: `_decide` returns `RouteCloud(CloudTier.mid)`, `generate` uses
  that provider, and `capabilities` reports its window.
- Wiring: `forcedCloud` returns the picked model's provider under
  `CloudDirect`. The existing `privacy` callback also returns
  `CloudPrivacy.localOnly` when the route is `LocalOnly`, so picking
  "On-device" keeps an overflowing Explain local.
- `ExplainNotifier`: add `bool Function()? needsConfirm`, default `() => true`
  (today's always-confirm). The run condition becomes
  `decision != null && !cloudConfirmed && needsConfirm()`. Wiring passes
  `needsSendConfirmation(...)` under `CloudDirect` and leaves the default under
  Auto. Explain keeps its own `ExplainConfirmCloud` state and does **not** use
  `CloudSendGate`.
- `ExplainConfirmCloud` gets an optional `modelName` so the confirm copy can
  name the model instead of a tier.

**Summarize** (`summarization_service.dart`, `summarize_notifier.dart`, `summarize_providers.dart`)
- Add `AiProvider? Function()? directCloud` to `SummarizationService`. When it
  returns a provider, `summarizeScope` **skips `_router.decide`** (which would
  demand a downloaded local model) and runs the same chunk-and-reduce on that
  provider, unguarded.
- To do that, refactor `_generateLocally`, `_chunkAndReduce` and
  `_summarizeOnce` to take the provider as a parameter. The budget comes from
  that provider's `capabilities`; `modelUsed` is its `displayName`; the tier is
  `AnswerTier.cloud`.
- Leave `CloudLlmClient`, `StubCloudLlmClient` and the `AiRoute.cloud` branch
  exactly as they are. Auto mode must not gain a silent cloud route.
- `SummarizeNotifier.run`: under `CloudDirect`, await the gate once before
  calling the service.

**Quiz and flashcards** (`ai_providers.dart`, `quiz_notifier.dart`, `flashcard_notifier.dart`)
- `quizGeneratorProvider` and `flashcardGeneratorProvider`:
  `provider: ref.watch(answerAiProvider)`.
- Each notifier awaits the gate once at the start of `generate` under
  `CloudDirect`; on decline, back to idle.
- A cloud reply that does not parse already ends in the existing "couldn't put
  a quiz together" error; add the on-device hint to that message under
  `CloudDirect`.

**Research** (`ai_providers.dart`, `research_notifier.dart`)
- `Researcher` is built with a client. Give it a small `ToolCallingClient` that
  resolves `activeToolsClientProvider` at call time and throws
  `AiUnavailableException("This model can't use tools. Pick another model for Research.")`
  when it is null.
- Read `ResearchNotifier.ask` (lines 90–120) and make its confirm condition use
  `needsSendConfirmation` under `CloudDirect`.

**Not changed in Part 1:** `writingAssistantProvider`, `contextEngineProvider`,
every vision provider, `figureQaProvider`, `aiQualityGuardProvider`,
`localModelWarmerProvider` (page analysis loads the local model under `auto`
whenever the panel is open, so warming is not wasted).

### 4.10 Key hygiene

- Add `String scrubSecrets(String text)` in `lib/core/error_log.dart` and apply
  it inside `ErrorLog._record`. Patterns: `Bearer\s+\S+`, `sk-[A-Za-z0-9_-]{16,}`,
  `AIza[0-9A-Za-z_-]{20,}`, and `([?&](?:key|api_key|token)=)[^&\s]+`.
- Never log a request, a header or a response body from the adapter.
- `.margo` export carries no preferences today. Add a test that keeps it so.
- The key field in the add screen is obscured, with a show toggle, and is never
  put in a snackbar or an error.

### 4.11 Screens

**Settings → AI models** (`ai_models_screen.dart` hosts sections from
`settings_ai_models.dart`; add `settings_cloud_models.dart`):

```
Cloud models
  From Margo
    Free          Coming soon
    Budget        Coming soon
    Premium  🔒   Use your own key instead
  Your keys
    My Groq                 2 models     ⋮
    Work OpenRouter         1 model      ⋮
    + Add an AI
  Your key is only used when you pick that model. Reading and
  analysing pages in the background never uses it.
```

**Add an AI** (`/settings/models/add`), one screen, four steps:

1. Provider: a list of presets, plus "Other (OpenAI-compatible)" with a URL field.
2. Name ("What do you want to call it?") and the key (obscured).
3. **Test.** `ModelConnectionTester` does `GET {baseUrl}/models` with the key.
   Success shows the model list. If the provider has no `/models`, show a typed
   model-id field and test with one 1-token chat call.
4. Tick the models to show in the picker; each can be renamed. Save.

`⋮` on a connection: rename, re-test, edit models, replace key, delete.

**Model picker** (`widgets/model_picker_sheet.dart`), opened from a chip in the
AI panel header next to the existing cloud switch (`ai_sidebar.dart`, about
lines 759–824), and by typing `/model`:

```
Answer with
  ● Auto                 On your device first
  ○ On-device (Gemma)    Nothing leaves this tablet
  ○ My Groq · llama…     Your key
  ○ Work OpenRouter · …  Your key
  Free · Budget · Premium     Coming soon
```

- The cloud switch stays as the master control.
- With cloud off, cloud rows are greyed with "Cloud AI is off — turn on".
- `chat_commands.dart`: add `ModelPickerCommand` for the exact input `/model`.
  Follow that file's rule: slash commands are exact; no natural-language match.
  Update `UnknownSlashCommand`'s hint text in `AskNotesNotifier._handleCommand`.

### 4.12 Build order

Each step is one commit, with its tests, and `flutter analyze` clean.

| # | Step | Done when |
| --- | --- | --- |
| 1 | Catalogue types, presets, `UserConnection` JSON | Round-trip tests pass. |
| 2 | `UserConnectionStore` | Add / edit / delete tests pass with `InMemorySecretStore`; the key is never in prefs. |
| 3 | `OpenAiCompatibleProvider` text streaming | Fake-adapter tests: chunks, `[DONE]`, comment lines, cut stream, every row of the error table, cloud-off sends nothing. |
| 4 | Tool calling in the adapter | Fragmented arguments reassemble; incomplete call errors; empty prompt adds no user turn. |
| 5 | `ModelConnectionTester` | Lists models; bad key → clear message; no `/models` → fallback path. |
| 6 | `answerModelId` setting, `resolveAnswerRoute`, `needsSendConfirmation` | Table-driven test over every `aiMode` × privacy × choice, incl. "stored cloud id, cloud off" and "id no longer exists". |
| 7 | `SelectedAnswerProvider`, catalogue and route providers, `CloudSendGate` | Dynamic capabilities test; gate tests (no-prompt path, allow, decline, timeout, second request declined). |
| 8 | Ask, quiz, flashcards onto the route; `AnswerTier.cloud`; banner | One test per feature per route. `askEachTime` + decline → the fake cloud receives nothing. |
| 9 | Explain (`forcedCloud`, `needsConfirm`) | Existing `explain_notifier_test` and `routing/` tests unchanged; new tests for `CloudDirect` and `LocalOnly`. |
| 10 | Summarize `directCloud` | Existing summarize tests unchanged; `CloudDirect` runs with no local model installed; chunk-and-reduce prompts once. |
| 11 | Research tool-client resolution | Text-only model → the "can't use tools" message; tools model → the loop runs against the fake. |
| 12 | `scrubSecrets`, export test | A key planted in an error never reaches the log file. |
| 13 | Settings section, add screen, picker sheet, `/model` | Widget tests; `chat_commands_test` extended. |
| 14 | Tablet check with a real key | Section 8, Part 1 list. |

Tests follow the existing patterns: a hand-written `HttpClientAdapter` fake as in
`test/features/ai/data/providers/cloud_gateway_provider_test.dart`; package
import prefix `package:margo/`.

One more test that guards the design: picking a user-key model must leave
`readModelId` and every provider in 2.3 unchanged (assert the read-cache model
id before and after `setAnswerModelId`).

### 4.13 Optional last step

A low-confidence answer in Auto, when the user has a connection, gets a second
button: "Ask <model name> instead". It re-asks through the `CloudDirect` path
with a one-shot override (`AskNotesNotifier.ask(..., modelOverride)`), behind
the gate. Skip it if Part 1 is running long.

---

## 5. Part 2: teacher persona for every feature

### 5.1 The constraint that shapes the design

`compactForWindow` swaps `kTutorVoice` and `kMathMarkup` for their compact
forms by exact-text `replaceAll`. `AiRouter.inputWordBudgetFor` and
`LocalGemmaProvider` both call it. So:

- New persona text must be **constants inserted verbatim**, each with a compact
  twin, and `compactForWindow` gains one `replaceAll` per new constant.
- Anything that varies per call (style, learner profile) cannot be compacted by
  `replaceAll`, so the code that builds it must be given the window size and
  leave it out itself.
- Feature prompts are `static const` today and are passed around by name
  (`NotesQa.systemPrompt` is used by the notifier, the guard call and
  `fitToBudget`). Keep the constant part constant, and add a dynamic tail.

### 5.2 New file `lib/features/ai/domain/tutor/tutor_prompt.dart`

Draft text. Read it aloud before committing; it has to obey `kTutorVoice`'s own
rules (no filler, no flattery).

```dart
/// Who is talking to whom. Shared by every feature that speaks to the student.
const String kTutorRole = '''
You are this student's teacher and study partner, inside the app they take their notes in. The person you are talking to is learning this material from their own notes. Success is that they understand it and can do it themselves afterwards, not that they were handed an answer.''';

/// How a good teacher behaves, as things that can be checked in a reply.
const String kTeachingRules = '''
How you teach:
- Start from what the student already wrote or said, and build the next step on it.
- One new idea at a time, in the order a learner needs them.
- Pitch it to their level. Use a technical term only if they have used it or you have just defined it.
- When they show their own thinking, say exactly what is right in it before you correct what is wrong, and name the specific gap.
- Prefer a worked example from their own material to a general statement.
- If you are not sure, or the material does not say, say so. Never make something up to keep the lesson moving.
- Do not flatter and do not scold.''';

const String kTutorRoleCompact =
    "You are this student's teacher and study partner; they are learning this from their own notes.";

const String kTeachingRulesCompact =
    'Build on what they wrote, one idea at a time, at their level. Say what is right before correcting what is wrong. If unsure, say so; never invent.';

enum TeachingStyle { explain, guide }

const String kStyleExplain =
    'Give the explanation directly. Then, where it helps, ask one short question that makes them use what you just explained.';

const String kStyleGuide = '''
Do not give the full answer first. Give one hint, or ask one question, that moves them a step closer, then stop. Give the full answer once they have tried, or as soon as they ask for it outright. If they ask for a definition, a fact or a formula, just give it: hints are for problems and reasoning.''';

/// For grounded features in guide style.
const String kStyleGuideGrounded =
    'Your hint must come from the passages too, never from outside them.';

class LearnerProfile {
  final KnowledgeLevel? level;            // LearningPreferences.preferredDifficulty
  final List<String> weakConcepts;        // up to 5, sanitised
  final ExplainMode? preferredMode;       // LearningPreferences.preferredExplainMode
  static const none = LearnerProfile(weakConcepts: []);
}

class TutorContext {
  final TeachingStyle style;
  final LearnerProfile profile;
  static const plain = TutorContext(style: TeachingStyle.explain, profile: LearnerProfile.none);
}

/// The part of a system prompt that changes per call. Goes LAST, so the long
/// constant part before it stays a stable prefix. Returns '' when there is
/// nothing to add.
String tutorTail(
  TutorContext context, {
  required int windowTokens,
  required bool allowCheckQuestion,   // false for Summarize
  required bool grounded,             // true for Ask
});
```

Profile block as it appears in a prompt:

```
About this student, from their study history in this app. Use it to pitch what you say. Never mention it.
- Level: intermediate
- Still shaky on: entropy, Gibbs free energy, Le Chatelier's principle
- Likes explanations that are: real-world
```

Rules for the tail:

- Window ≤ 2,048 (`kCompactPromptWindowTokens`): no profile block; style is one
  line.
- Concept names come from text a model extracted from the student's notes, so
  treat them as untrusted: keep letters, digits, spaces and `-'()`, cut each to
  40 characters, drop empties, take at most 5.
- Empty profile fields are left out, not guessed. An empty profile adds nothing.
- `allowCheckQuestion: false` drops the question sentence from the style line.

### 5.3 `compactForWindow`

Add the two new pairs:

```dart
.replaceAll(kTutorRole, kTutorRoleCompact)
.replaceAll(kTeachingRules, kTeachingRulesCompact)
```

### 5.4 Per-feature composition

`{mode}` and `{tail}` are added at call time; everything else is `const`.

| Feature | System prompt, in order | Notes |
| --- | --- | --- |
| Ask (`NotesQa`) | `kUntrustedDataRule` · the grounding contract, unchanged and still first · `kTutorRole` · `kTeachingRules` · `kTutorVoiceWithMath` · `{tail}` | Remove the old opening words "You are a tutor answering…" only where `kTutorRole` now says it; keep every grounding sentence and the exact refusal string `notFoundReply`. |
| Explain (`Explainer._base`) | `kUntrustedDataRule` · `kTutorRole` (replaces "You are a patient tutor helping one student…") · `kTeachingRules` · `kTutorVoiceWithMath` · the existing "Explain the SUBJECT…" paragraph · `{mode}` · `{tail}` | |
| Summarize (`_voice`) | `kUntrustedDataRule` · `kTutorRole` · the existing recap sentence · `kTeachingRules` · `kTutorVoiceWithMath` · the existing recap rules | `allowCheckQuestion: false`; Summarize passes style only as far as it needs, and its prompt already says a recap is not the place for a question. |
| Research (`Researcher.systemPrompt`) | `kUntrustedDataRule` · `kTutorRole` · `kTeachingRules` · `kTutorVoiceWithMath` · the existing tool-use sentences · "Say where a fact came from when you looked it up." · `{tail}` | Has no voice today. Check the research view renders maths before adding `kMathMarkup`. |
| Figure Q&A | unchanged | Its output is a short extraction that Ask folds in as a passage; it is not spoken to the student. |
| Quiz, flashcards | Add one line: "Write for a student at {level} level, in the words their notes use." Feedback and explanation strings follow `kTutorVoiceCompact`. | JSON output; no persona block. |
| Writing suggestions | Add the same one-line level hint. | Background, JSON. |
| Context Engine | unchanged | Extraction, not teaching. |

API changes:

- `NotesQa.systemPromptFor(TutorContext context, {required int windowTokens})`;
  keep `static const systemPrompt` as the constant part (tests pin it).
  `promptFor`, `fitToBudget` and the notifier's guard call take the composed
  string.
- `Explainer.systemPromptFor(mode, [TutorContext context = TutorContext.plain, int? windowTokens])`.
- `tutorContextProvider(notebookId)`: a `FutureProvider.family` that reads
  `LearningMemoryRepository.weakConcepts(notebookId)` (first 5) and
  `loadPreferences()`, plus the `teachingStyle` setting. Notifiers read it
  before generating; it is a small Isar read.

### 5.5 New settings and UI

- `teachingStyle` in `SettingsState`, key `ai.teachingStyle`, default `explain`.
- A two-state control in the AI panel ("Explain" / "Guide me") and in Settings.

### 5.6 `TutorOutputShape`

`kTutorVoice` forbids headings and lists, right for talk and wrong for a study
guide. Add `kTutorVoiceStudyMaterial`: the same voice with that one bullet
replaced by "Use short headings and lists where they help someone revise."
Nothing uses it until Part 4 (study guide, FAQ); add it here so the voice has
one home.

### 5.7 Budget check (must hold)

Rough costs at 3.5 characters per token: untrusted rule ~50, Ask contract ~170,
`kTutorVoice` ~600, `kMathMarkup` ~130, role ~75, rules ~150, style ~40,
profile ~60. Ask's full system prompt goes from about 950 to about 1,275
tokens.

| Window | Left for passages (window − 512 − 200 − system) | Requirement |
| --- | --- | --- |
| 4,096 | about 2,100 tokens ≈ 1,560 words | Must stay ≥ 1,250 words, i.e. five 250-word passages. |
| 2,048 (compact) | about 950 tokens ≈ 700 words | Must not drop more than 60 words below today's figure. |

Write both as tests beside `test/features/ai/domain/lite_window_budget_test.dart`,
using `AiRouter.inputWordBudgetFor` on the real composed prompts. If the 4,096
figure fails, shorten `kTeachingRules` before touching `kTutorVoice`.

### 5.8 Tests and review

- `tutor_voice_test.dart`: the new constants compact correctly; a composed
  prompt contains each constant verbatim.
- Exact-prompt tests per feature (the repo already pins prompts this way).
- "Grounding comes before persona" for Ask: the index of the grounding sentence
  is lower than the index of `kTutorRole`.
- `grounding_audit_test.dart` and every existing Ask refusal test pass
  unchanged.
- `tutorTail`: empty profile → `''`; small window → no profile; hostile concept
  name (newline, "ignore previous instructions") is neutralised.
- Human read: a fixed set of about 20 questions (definition, worked problem,
  wrong student reasoning, follow-up, not-in-notes, a maths formula) run on the
  on-device model and one cloud model in both styles from a dev screen. What to
  look for: no flattery, one idea at a time, the check question is specific,
  the guide style really withholds the answer, grounded answers never go
  outside the passages. `quality/output_quality.dart` already catches empty and
  looping output.

### 5.9 Build order

1. Constants, `compactForWindow`, tests.
2. `LearnerProfile`, `TutorContext`, `tutorTail`, sanitiser, tests.
3. `tutorContextProvider`, `teachingStyle` setting.
4. Ask. 5. Explain. 6. Summarize. 7. Research. 8. Quiz, flashcards, writing line.
9. Budget tests. 10. Style control in the panel. 11. The 20-question read.

---

## 6. Part 3: our free, budget and premium tiers

### 6.1 Open decision to put to the user first: hosting

Render's free plan sleeps after about 15 minutes and takes 30–60 s to wake
(`gatewayDio` already allows 60 s for it). No app-side work hides that. Options:

| Option | Cost | Effort | Note |
| --- | --- | --- | --- |
| Render paid, always on | a few dollars a month (verify) | none | Also allows a disk so the usage counters survive a restart (`render.yaml` says they reset today). |
| Move the proxy to an edge runtime | usage-based, often free at this scale | rewrite of a ~600-line Python service | No cold start. The Python adapters, guards and tests would need porting. |
| Stay on free | zero | none | First question after a quiet spell waits up to a minute. |

Recommendation: always-on Render first (no code), measure, reconsider later.

### 6.2 Server changes (`server/ai-gateway/`)

**Catalogue** — new `app/catalog.py`, loaded from a `MODEL_CATALOG_JSON`
environment value with a default list in code:

```python
@dataclass(frozen=True)
class CatalogEntry:
    id: str                  # "free", "budget", "premium-1" … stable, app-facing
    display_name: str
    tier: str                # "free" | "budget" | "premium"
    provider: str            # "openrouter" | "gemini" | "claude" | "gpt"
    upstream_model: str
    context_window: int
    supports_tools: bool
    supports_vision: bool
    locked: bool
    daily_request_cap: int   # per device
    global_request_cap: int  # across all devices, per day
```

**`GET /v1/models`** → `{"models": [{id, display_name, tier, context_window,
supports_tools, supports_vision, locked, available}], "version": "<hash>"}`.
`available` is false when the entry's provider key is not configured. No
upstream ids or provider names leave the server.

**`POST /v1/generate`** — add `model: str | None`. If present it wins and is
looked up in the catalogue; if absent, `model_tier` keeps working for old
builds. A locked entry returns 403 `{"detail": "locked"}`. An unknown id
returns 400. Do this before the caller is charged, as the file's existing
comment requires.

**Rate limits** (`app/rate_limit.py`)
- New table `tier_usage(device_key TEXT, day TEXT, tier TEXT, requests INTEGER,
  PRIMARY KEY (device_key, day, tier))`, plus a `__global__` row per tier, with
  the same check-and-record and refund discipline as `RateLimiter`.
- Free tier: `daily_request_cap` 5–10 (the user's numbers; start at 10).
- `global_request_cap` for the free tier must be **the real upstream quota**.
  Today `GLOBAL_REQUEST_CAP` is 5,000, while a free upstream account was
  reported at about 50 requests a day (about 1,000 with paid credit on the
  account). Verify both before setting.
- An upstream 429 becomes HTTP 429 with `{"detail": "free_exhausted"}` so the
  app can say "free cloud is used up for today" instead of a provider error.
- Response headers on every generate: `X-Quota-Limit`, `X-Quota-Remaining`.

**Which free model** — verify at the time. Two candidates: an OpenRouter
`:free` Gemma variant (small shared quota), or Gemma through Google's API,
where a third-party page reported a far larger daily allowance. The server
already has `gemini_provider.py`; check whether it can serve Gemma model ids.

**Premium** — entries with `locked: true`. Nothing else until billing exists.

**Known limit, stated plainly:** `X-Device-Key` is chosen by the app, so
resetting the app resets a per-device cap. Per-device caps bound honest use;
the global cap bounds spend. Real enforcement needs billing or device
attestation (`docs/SECURITY_REVIEW.md` item 2, "Gateway has no caller
authentication").

Tests in `server/ai-gateway/tests/`: catalogue parsing, `/v1/models`, model
selection and back-compat, locked → 403, tier caps, global cap, refund on
failure, the 429 mapping, quota headers.

### 6.3 App changes

- `data/catalog/margo_catalog.dart`: `MargoCatalogRepository` fetches
  `/v1/models`, caches the JSON and fetch time in prefs (`ai.margoCatalog`),
  refreshes after 24 h or when the picker opens, and falls back to the bundled
  list (all unavailable) when it has never succeeded.
- `CloudGatewayProvider`: add an optional `modelId` sent as `model`, keep
  `model_tier`. One instance per catalogue entry, cached.
- `_mapError`: 403 `locked` → "This model isn't available yet"; 429
  `free_exhausted` → `AiUnavailableException("Free cloud is used up for today.
  On-device still works.")`.
- Read the quota headers into a small provider and show "3 of 10 free
  questions left today" under the picker row.
- Running out offers: on-device, or "use your own key".
- `resolveAnswerRoute` rule 4 now finds a real escalation target, so Auto's
  quality re-run works again. `aiQualityGuardProvider`'s `cloud` should become
  that entry's provider instead of the fixed `cloudGatewayMidProvider`.
- `toolsProvider` includes web search again once the tier is available.

### 6.4 Build order

Hosting decision → deploy and confirm `/health` → catalogue + `/v1/models` →
`model` on generate → tier limits and headers → app catalogue fetch and cache →
picker shows real entries and quota → end-to-end on the tablet.

---

## 7. Part 4: tutor conversation and retrieval (design sketch)

This part needs a short design session of its own once Parts 1 and 2 exist,
because its shape depends on how they landed. What follows is the intended
design and the reasoning, so that session starts from decisions, not a blank
page.

**Approval needed before 4b:** saved chats mean new Isar collections and a
migrator test (HANDOVER rules 3 and 4).

### 7.1 Why

NotebookLM's value is three things Margo's Ask lacks: it remembers the
conversation, every claim links to the passage it came from, and it offers
ready-made study material from the same sources. Margo already has sources
(pages, PDFs, lecture transcripts), scoped retrieval, quizzes, flashcards, a
concept graph and a study planner. They are separate buttons; this part joins
them into one tutor.

### 7.2 Pieces, in build order

**4a Conversation, session-only (no schema change).**
- `AskNotesNotifier` holds a list of turns for the open notebook and passes
  recent turns as `history` (the contract and both providers already accept it).
- Follow-up retrieval **without an extra model call**: the search query is the
  new question plus the content words of the previous question (use
  `keywordTokens` from `hybrid_search.dart` to drop stop words). Embed that one
  combined string.
- History budget: keep the last turns that fit in about a quarter of the input
  window; on the 4,096 window that is roughly one previous exchange. Passages
  always get priority over history.
- The on-device provider replays history with `session.addTurn`, which costs
  time per turn; measure before raising the limit (see 9).
- The UI changes from one answer to a scrolling thread. The states in
  `ask_notes_notifier.dart` describe one answer; they become the state of the
  latest turn.

**4b Saved threads (schema change, ask first).**
```
ChatThreadRecord { id, notebookId, title, createdAt, updatedAt, rollingSummary }
ChatTurnRecord   { id, threadId, role, text, sourcesJson, modelName, tier, createdAt }
```
- `sourcesJson` stores chunk ids and page ids, not passage text, so a deleted
  page cannot leave its text behind.
- A rolling summary replaces older turns when a thread outgrows the window;
  write it with the answering model at the end of a turn, in the background.
- Deleting a notebook deletes its threads. Threads are not in `.margo` exports
  unless the user asks for that.

**4c Retrieval quality.**
- Top-K from the model's window: 5 on-device as now; for larger windows, as
  many passages as fit in about half the input budget, capped at 20.
- Neighbour expansion: when a chunk is chosen, also load the chunk before and
  after it on the same page if they fit (chunk ids are `pageId:ordinal`).
- Diversity: after ranking, do not take more than half the passages from one
  page unless the scope is that page.
- Passage headers carry the page number and document name so the model can say
  where something is: `[2] (Thermodynamics.pdf, p. 14) …`.
- Measure `kMinRelevance` on real notes using `presentation/rag_corpus_export.dart`.
  It is still the provisional 0.45.

**4d Citations.**
- Render `[n]` in an answer as a tappable chip. Tap opens the page and tints
  the passage with `SearchHighlightLayer` (roadmap step 16). `onJumpToSource`
  already exists on `AiSidebar`.
- An answer that cites a number it was not given is flagged; add the check to
  `quality/output_quality.dart`.

**4e Two engines behind one interface.**
```dart
abstract class TutorEngine { Stream<TutorEvent> respond(TutorTurn turn); }
```
- `PipelineEngine` for on-device and text-only models: decide intent →
  retrieve → answer. Fixed steps, no extra model calls.
- `AgentEngine` for cloud models with `supportsTools`: the model decides what
  to look up. Tools: `search_notes(query, scope)`, `read_page(page_number)`,
  `learner_profile()`, `make_quiz(topic)`, `make_flashcards(topic)`, plus the
  existing calculator, Wikipedia and web search. Generalise `Researcher`'s loop
  and keep its bound of three tool hops.
- Tool results are untrusted text: fence them with `fenceUntrusted`, as
  `Researcher` already does for its tools.
- Keeping two engines is the efficiency decision: a 2B on-device model with a
  4,096-token window cannot run an agent loop, and pretending it can would make
  every answer slow.

**4f Intent without a model call.**
- Slash commands and chips: `/quiz`, `/flashcards`, `/explain`, `/summarize`,
  `/plan`, routed to the generators that exist. Exact match only, per
  `chat_commands.dart`.
- A question the notes do not cover keeps the honest "not in your notes", with
  a labelled offer: "Answer from general knowledge". That answer carries a
  different banner so it is never mistaken for a grounded one.

**4g Notebook guide.**
- Per notebook: a short overview, key topics, and three to five suggested
  questions. Topics come from concepts the Context Engine already recorded in
  Learning Memory (no new model pass). Suggested questions are one model call,
  cached against a hash of the notebook's text.
- Study guide and FAQ use `kTutorVoiceStudyMaterial` from Part 2.

**4h Learning loop.**
- A question about a concept is a weak-concept signal; record it in Learning
  Memory.
- After an answer: "Quiz me on this" builds a short quiz from the cited pages.
- Quiz results already update mastery; the planner already reads it.

---

## 8. Part 5: speed and efficiency, and verification for every part

### 8.1 Speed and efficiency

Measure first. Several items below land naturally inside earlier parts; this
part is the pass that checks them with numbers.

**Measure**
- A dev screen, following `presentation/dev/figure_benchmark_screen.dart`:
  time to first word, words per second, total time, retrieval time, by model
  and feature. Local only; nothing is uploaded.

**Targets**

| Measure | Target |
| --- | --- |
| Retrieval, warm embedder | under 300 ms |
| Cloud, time to first word | under 1.5 s on Wi-Fi |
| On-device, time to first word | already known: 3.6–17 s cold on the reference tablet, hidden by warming |
| Extra model calls per on-device answer | zero (no model-based router, no query rewrite) |

**Checklist**
- Own-key calls go direct (Part 1), one hop.
- One long-lived `Dio` per connection (Part 1), so TLS is not renegotiated per
  question.
- When the AI panel opens: warm the embedder, and send `GET /health` to the
  gateway if our tier is in use. Same idea as `localModelWarmerProvider`.
- Stable prompt prefix (Part 2's block order) so providers' prompt caching can
  apply. Native adapters with explicit cache controls come later.
- A new question cancels the one in flight (the `CancelToken` is there).
- Output length is capped per feature already (`maxTokens: 512` and so on);
  keep it when adding features.
- `rag_retriever.dart` re-tokenises every chunk on every query (there is a note
  in the code). Cache tokens per chunk.
- Move the cosine sweep to an isolate once a notebook passes a measured size.
- Background work never uses a paid model (Part 1 rule).
- A failed cloud model offers on-device; it never silently switches provider.

### 8.2 Verification

**Every part**
- `flutter analyze` clean.
- `flutter test` green. The suite was about 3,170 tests on 2026-11-16, with one
  known flaky test in `test/core/error_log_test.dart` that passes alone.
- `graphify update .`

**Part 1, on the tablet with a real key** (an OpenRouter key on a free model
costs nothing)
1. Add a connection, test it, tick a model, pick it.
2. Walk every row of the routing table in 4.8. Confirm on the provider's usage
   page which requests arrived: Ask, Explain, Summarize, quiz and flashcards
   each add requests and show the model's name; opening and editing pages adds
   none.
3. Privacy `askEachTime`: every action prompts once (Summarize of a long
   notebook prompts once, not once per chunk). Decline → nothing arrives.
4. `/cloud off`, then ask: nothing arrives; the answer is on-device.
5. Aeroplane mode with the cloud model picked: a clear error naming the host.
6. Wrong key: "rejected the key", no key text anywhere on screen.
7. Delete the connection: the picker falls back to Auto. Then share the error
   log and export a `.margo`, and search both for the key.
8. A device with no on-device model downloaded: Ask, Explain, quiz and
   Summarize work with the cloud model picked.

**Part 2** the 20-question read in 5.8, on-device and cloud, both styles.

**Part 3** `cd server/ai-gateway && pytest`; then on the tablet: free model
answers, the counter counts down, the cap message appears, a locked model
cannot be picked.

**Part 4** follow-up questions resolve ("and what about its units?"), citations
jump to the right page, a deleted page leaves no text in a saved thread.

---

## 9. Not verified, or assumed: check before relying on it

| # | Claim | How to check |
| --- | --- | --- |
| 1 | Provider base URLs, model ids, free limits | Each provider's own documentation. Planning used third-party pages. |
| 2 | `max_tokens` vs `max_completion_tokens`, and which models reject `temperature` | Provider documentation; a 400 response names the bad parameter. |
| 3 | Anthropic's OpenAI-compatible endpoint | Load the `claude-api` skill before writing anything Anthropic-specific. |
| 4 | `AnswerTier` is not stored in Isar | `graphify query "where is AnswerTier used"`, then grep the `.g.dart` files. If it is stored, appending is still allowed (append-only), but add a migrator test. |
| 5 | `flashcard_notifier.dart` has the same shape as `quiz_notifier.dart` | Read it. |
| 6 | `ResearchNotifier.ask`'s confirm condition | Read `research_notifier.dart` lines 90–120. |
| 7 | Whether quiz, flashcard and research views render maths through `MathText` | Read the views before adding `kMathMarkup` to those prompts. |
| 8 | Layout of `settings_ai_models.dart` (597 lines) and the cloud switch widget in `ai_sidebar.dart` | Read both before placing the new section and the chip. |
| 9 | Every `CloudDirect` call starts from the editor screen (one gate listener is enough) | `graphify query "who calls QuizNotifier.generate / FlashcardNotifier / SummarizeNotifier.run"`. |
| 10 | Gateway frontier adapters work | `providers/base.py` says they are untested against a live key. |
| 11 | The gateway is not deployed | It returned 404 on 2026-11-16. It may exist under another name; ask the user. |
| 12 | `kMinRelevance = 0.45` | The code marks it provisional; measure in Part 4. |
| 13 | Cost of replaying history on the on-device model | Measure on the tablet in Part 4a. |
| 14 | Token costs in 5.7 | Estimates at 3.5 characters per token; the tests in 5.7 are the real check. |
| 15 | `SummaryCache.modelUsed` is a free-text field that can hold a model's display name | Read `lib/features/summarize/data/cache/summary_cache.dart`. |
| 16 | NotebookLM features described in 7.1 | From Google's education pages and third-party guides read on 2026-11-16; used only as direction. |

---

## 10. Open decisions (the user's to make)

| # | Decision | Needed before | Author's suggestion |
| --- | --- | --- | --- |
| 1 | Confirm the six calls in section 1 | Part 1 | As written |
| 2 | Should Explain in Auto stop asking every time it goes to the cloud, when privacy is "allow"? | Part 1 step 9 | Leave as it is |
| 3 | The exact per-user free cap: 5 or 10 a day | Part 3 | 10 |
| 4 | Gateway hosting | Part 3 | Always-on Render, then measure |
| 5 | Which model backs the free and budget tiers | Part 3 | Decide from verified quotas and prices at the time |
| 6 | Approve the Isar change for saved chats | Part 4b | Yes, after 4a is used for a while |
| 7 | Should saved chats travel in `.margo` backups? | Part 4b | Off by default |
| 8 | Local-network servers (Ollama, LM Studio) as connections | After Part 1 | Later; needs Android cleartext rules |
| 9 | A setting to let vision use a chosen model | After Part 3 | Later |
| 10 | Billing for premium | After Part 3 | Its own project |
| 11 | How should the student stop being asked on every question to a model they picked? `CloudPrivacy` has no control today. | Part 1 step 13 | A "Don't ask again for this model" tick on the dialog, stored per connection. Do **not** reuse `allowCloudForNonSensitive` for it: that value also lets page images upload and pages be analysed in the cloud without asking. |
| 12 | Should there be a privacy control in Settings at all (ask each time / allow / local only)? | Part 1 step 13 | Yes, in the AI models screen, with one line under each option saying exactly what it allows |
| 13 | Order after Part 1: retrieval quality and persona before our tiers? | After Part 1 | Yes: Part 2, then Part 4c, then Part 3 |

---

## 11. Where the strongest available model matters

The user asked (2026-11-16) which pieces the plan's author should code
personally. Fable access ends 2026-11-17 and this work starts after the
roadmap, so the practical rule for whoever builds it is: put the strongest
model you have on the rows marked High, and call the advisor before each.

| Piece | Risk | Why |
| --- | --- | --- |
| Part 1 steps 6–11 (route function, consent gate, wiring each feature) | **High** | Privacy rules cross six features. The first two drafts of this plan got the routing wrong; a mistake here sends note text to a third party without asking. |
| Part 1 step 4 (tool-call fragments in the adapter) | Medium | Easy to get subtly wrong; the Python version to port from is correct and tested. |
| Part 2 persona text and the 20-question read | **High** | Judgment about wording, and the grounding promise must survive it. Draft text is in 5.2. |
| Part 4 design session, and 4e (two engines) | **High** | The remaining open design work. |
| Part 1 steps 1–3, 5, 12–13; Part 3; Part 5 | Routine | Clear acceptance checks. Sonnet-level work. |

Nothing in this plan is low-level model optimisation (kernels, quantisation,
runtime tuning). The tuning here is prompt wording, the retrieval threshold and
latency, all measured on the tablet.

---

## 12. Sources read while planning (2026-11-16)

- Own-key design: https://dev.to/apoorvdarshan/designing-a-bring-your-own-key-byok-architecture-on-ios-45id ·
  https://tianpan.co/blog/2026-05-14-byok-ai-features-sales-driven-rearchitecture
- OpenAI-compatible endpoints: https://www.developersdigest.tech/reference/api-compatibility ·
  https://docs.openwebui.com/getting-started/quick-start/connect-a-provider/starting-with-openai-compatible.txt
- NotebookLM: https://edu.google.com/intl/ALL_no/ai-notebooklm ·
  https://www.eweek.com/news/google-notebooklm-cheat-sheet-2026/
- Teaching principles (LearnLM: active learning, managing cognitive load,
  curiosity, adapting to the learner, metacognition):
  https://services.google.com/fh/files/misc/googlespedagogicalframework.pdf ·
  https://garyliang.substack.com/p/google-learnlm-technical-paper
- Free limits: https://openrouter.ai/pricing ·
  https://openrouter.zendesk.com/hc/en-us/articles/39501163636379-OpenRouter-Rate-Limits-What-You-Need-to-Know
- Latency: https://redis.io/blog/api-latency-llm-apps/ ·
  https://tianpan.co/blog/2025-10-30-llm-latency-optimization-production
