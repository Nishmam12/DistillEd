# Graph Report - .  (2026-07-29)

## Corpus Check
- Large corpus: 413 files · ~3,105,037 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 5828 nodes · 7760 edges · 197 communities (194 shown, 3 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 29 edges (avg confidence: 0.54)
- Token cost: 9,200 input · 3,600 output

## Community Hubs (Navigation)
- Scene Element Persistence Records
- Concept Mastery Records
- Legacy Shape Element Models
- Concept Relation Records
- Study Plan Records
- RAG Note Chunk Records
- Quiz Attempt Records
- Notebook Domain Models
- Summary Cache Storage
- Study Session Records
- Note Page Models
- Flashcard Records
- Legacy Imported Content
- Isar Schema Glue
- AI Sidebar Views
- Learning Preferences Records
- Scene Canvas Widget
- Home Note Card Widgets
- Notebook Editor Screen
- AI Context View
- Notes Screen And Providers
- AI Riverpod Providers
- Settings Screen
- Summarization Service
- Gateway Rate Limiting
- Gateway Model Providers
- Scene Element Domain Model
- App Color Constants
- Editor Control Bars
- Anki Collection Export
- Handwriting Ink Lines
- Concept Mastery Domain
- Quiz Sheet UI
- AI Ask View
- Ask Notes Notifier
- Summarize Notifier
- Editor Tool Controller
- Canvas Interaction Glue
- AI Research View
- Scene Element Painter
- Flashcard Sheet UI
- Explain Notifier
- Quiz Notifier
- Study Planner Screen
- Flashcard Notifier
- Study Plan Domain
- Knowledge Graph Screen
- Legacy Stroke Adapters
- Learning Memory Repository
- Handwriting Recognition Service
- Quiz Generator
- Notebook Book View
- Context Engine Notifier
- Page Context And Preferences
- Viewport Controller
- Scene Domain Services
- Settings Provider
- AI Tool Implementations
- Scene Pointer Input
- Intelligent Model Router
- Gemma LLM Adapter
- Notes Color Palette
- Gateway Endpoint Tests
- Tool Options Overlay
- Provider Selection Tests
- Research Notifier
- Note Chunk And Summary Store
- Page Chunker
- Gateway Generate Router
- Selection Controller And Router
- Scene Geometry And Hit Test
- Pixel Eraser Service
- Editor Bottom Bar
- Scene Render Layers
- PDF Import Service
- Scene Exporter
- Page Content Extractor
- Model Download Manager
- Embedder Adapter
- Shared UI Widgets
- Writing Assistant
- Calculator Tool
- Embedder Download Manager
- Knowledge Graph Domain
- Scene Import Service
- RAG Index Scheduler
- Scene Controller
- Scene Element Codec
- OCR Layout
- Note Card Data
- App Entry Point
- Color Palette And Download UI
- Quiz Attempt Domain
- Path Geometry Utils
- Flashcard And Library Models
- Graph Layout
- AI Capabilities And Migration
- Scene Commands
- AI Message Model
- Anki APKG Export
- PNG Size Utils
- Clipboard And Device Storage
- Gemma Vision OCR
- History Controller
- Writing Assistant Notifier
- Template Config
- LLM Model Spec
- Local Gemma Provider
- Researcher Feature
- Page Content Model
- Search Bar Widget
- Scene Element Store
- Scene Editor Screen
- Cloud Gateway Provider
- Page Notifier
- Library Repository
- Embedder Spec
- RAG Retriever
- Image Text Recognition
- AI Router
- Explainer Feature
- Concept Relation Domain
- Text Budget
- Gateway Search Tool Tests
- Scene Export And Transcribe
- Isar Record Schemas
- Selection Overlay Layer
- Editable Note Title
- AI Generation Options
- Record Serialization Glue
- Selection Bounds
- Background Layer
- Fit Image Rect
- LLM Exceptions
- Study Scheduler
- Scene Image Cache
- Local Text Embedder
- Flashcard CSV Export
- Context Engine
- Meaningfulness Gate
- Vector Math
- Flashcard Generator
- Laser Pointer Layer
- Study Planner Notifier
- Study Session Domain
- Note Repository
- Recognition Result
- Stroke Point Model
- Ref Counted Cache
- Shape Geometry
- Cloud LLM Client
- Page Repository
- Notes QA Feature
- Home Notifier
- Template Painter
- Snap Engine
- Tool Interface
- Summarize Providers
- Autosave Controller
- Study Plan Store
- Scene Migrator
- Legacy Ink File Storage
- Migration Gate
- Tool Generation Events
- AI Exceptions
- App Theme
- Export Share Service
- Library Controller
- Note Chunk Store
- Legacy Page Source
- Active Stroke Layer
- Gateway App And Docs
- Isar Scene Element Store
- Z Order Service
- Rough Renderer
- Research Notifier Extras
- AI Provider Interface
- Flashcard Store
- Element Bounds
- Scene Image Cache Provider
- About Screen
- Library Service
- Storage Path Constants
- Text Embedder Interface
- Cross Record References
- Note Scene Preview
- Element Style Model
- Scene Element Variants
- Isar Service
- Stable ID Generation
- Dev Secrets Example
- Shape Type Enum
- Unresolved Exception Node

## God Nodes (most connected - your core abstractions)
1. `ChatTurn` - 24 edges
2. `Settings` - 23 edges
3. `sceneControllerProvider` - 22 edges
4. `ProviderError` - 22 edges
5. `selectionProvider` - 21 edges
6. `select_provider()` - 16 edges
7. `editorToolProvider` - 15 edges
8. `explainNotifierProvider` - 15 edges
9. `settingsProvider` - 14 edges
10. `historyProvider` - 14 edges

## Surprising Connections (you probably didn't know these)
- `Daily Search Cap` --semantically_similar_to--> `RateLimitConfig`  [INFERRED] [semantically similar]
  server/ai-gateway/README.md → server/ai-gateway/app/rate_limit.py
- `X-Device-Key Header` --references--> `RateLimiter`  [EXTRACTED]
  server/ai-gateway/README.md → server/ai-gateway/app/rate_limit.py
- `Gemma Cloud Tier Fallback` --references--> `Settings`  [INFERRED]
  server/ai-gateway/README.md → server/ai-gateway/app/config.py
- `Model Tier Routing` --references--> `UnknownModelTierError`  [INFERRED]
  server/ai-gateway/README.md → server/ai-gateway/app/provider_selection.py
- `anthropic Dependency` --references--> `ClaudeProvider`  [EXTRACTED]
  server/ai-gateway/requirements.txt → server/ai-gateway/app/providers/claude_provider.py

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Model Provider Abstraction** — server_ai_gateway_app_providers_base_modelprovider, server_ai_gateway_app_providers_claude_provider_claudeprovider, server_ai_gateway_app_providers_gemini_provider_geminiprovider, server_ai_gateway_app_providers_gpt_provider_gptprovider, server_ai_gateway_app_providers_gemma_cloud_provider_gemmacloudprovider [EXTRACTED 1.00]
- **Tool Calling Flow** — server_ai_gateway_readme_tool_calling_loop, server_ai_gateway_app_routers_generate_sse_stream_with_tools, server_ai_gateway_app_providers_gemma_cloud_provider_gemmacloudprovider_generate_with_tools, server_ai_gateway_readme_web_search_tool, server_ai_gateway_app_routers_tools_search_exa [INFERRED 0.85]
- **Per-Device Rate Limiting** — server_ai_gateway_readme_device_key, server_ai_gateway_readme_daily_search_cap, server_ai_gateway_app_rate_limit_ratelimiter, server_ai_gateway_app_rate_limit_searchratelimiter [INFERRED 0.85]

## Communities (197 total, 3 thin omitted)

### Community 0 - "Scene Element Persistence Records"
Cohesion: 0.00
Nodes (518): anyId, anyNotebookId, anyPageId, _appMetaAttach, _appMetaDeserialize, _appMetaEstimateSize, _appMetaGetId, _appMetaGetLinks (+510 more)

### Community 1 - "Concept Mastery Records"
Cohesion: 0.01
Nodes (157): anyId, anyNotebookId, bytesCount, conceptKeyBetween, conceptKeyContains, conceptKeyEndsWith, conceptKeyEqualTo, conceptKeyGreaterThan (+149 more)

### Community 2 - "Legacy Shape Element Models"
Cohesion: 0.01
Nodes (151): bytesCount, colorBetween, colorEqualTo, colorGreaterThan, colorLessThan, endBindingIdBetween, endBindingIdContains, endBindingIdEndsWith (+143 more)

### Community 3 - "Concept Relation Records"
Cohesion: 0.01
Nodes (143): anyId, anyNotebookId, bytesCount, _conceptRelationRecordAttach, _conceptRelationRecordDeserialize, _conceptRelationRecordEstimateSize, _conceptRelationRecordGetId, _conceptRelationRecordGetLinks (+135 more)

### Community 4 - "Study Plan Records"
Cohesion: 0.01
Nodes (136): anyId, anyNotebookId, bytesCount, completedEqualTo, conceptNameBetween, conceptNameContains, conceptNameEndsWith, conceptNameEqualTo (+128 more)

### Community 5 - "RAG Note Chunk Records"
Cohesion: 0.01
Nodes (134): anyId, anyNotebookId, anyPageId, bytesCount, contentSignatureBetween, contentSignatureContains, contentSignatureEndsWith, contentSignatureEqualTo (+126 more)

### Community 6 - "Quiz Attempt Records"
Cohesion: 0.02
Nodes (124): anyId, anyNotebookId, attemptIdBetween, attemptIdContains, attemptIdEndsWith, attemptIdEqualTo, attemptIdGreaterThan, attemptIdIsEmpty (+116 more)

### Community 7 - "Notebook Domain Models"
Cohesion: 0.02
Nodes (114): anyId, anyPageCount, backgroundColorBetween, backgroundColorEqualTo, backgroundColorGreaterThan, backgroundColorLessThan, backgroundColorProperty, bytesCount (+106 more)

### Community 8 - "Summary Cache Storage"
Cohesion: 0.02
Nodes (104): anyId, anyNotebookId, bytesCount, createdAtBetween, createdAtEqualTo, createdAtGreaterThan, createdAtLessThan, createdAtProperty (+96 more)

### Community 9 - "Study Session Records"
Cohesion: 0.02
Nodes (103): anyId, anyNotebookId, bytesCount, distinctByDurationSeconds, distinctByFeaturesUsed, distinctByNotebookId, distinctBySessionId, distinctByStartedAt (+95 more)

### Community 10 - "Note Page Models"
Cohesion: 0.02
Nodes (94): anyId, anyNotebookId, bytesCount, createdAtBetween, createdAtEqualTo, createdAtGreaterThan, createdAtLessThan, createdAtProperty (+86 more)

### Community 11 - "Flashcard Records"
Cohesion: 0.02
Nodes (93): anyId, anyNotebookId, anyPageId, backBetween, backContains, backEndsWith, backEqualTo, backGreaterThan (+85 more)

### Community 12 - "Legacy Imported Content"
Cohesion: 0.02
Nodes (87): bytesCount, heightBetween, heightEqualTo, heightGreaterThan, heightLessThan, idBetween, idContains, idEndsWith (+79 more)

### Community 13 - "Isar Schema Glue"
Cohesion: 0.02
Nodes (81): ShapeElementQueryFilter, ShapeElementQueryObject, AppMetaQueryFilter, AppMetaQueryLinks, AppMetaQueryObject, AppMetaQueryProperty, AppMetaQuerySortBy, AppMetaQuerySortThenBy (+73 more)

### Community 14 - "AI Sidebar Views"
Cohesion: 0.04
Nodes (75): ai_ask_view.dart, ai_context_view.dart, ai_explain_view.dart, ai_research_view.dart, ../ask_notes_notifier.dart, ConsumerWidget, ../core/theme/app_theme.dart, ../../data/llm/llm_model_spec.dart (+67 more)

### Community 15 - "Learning Preferences Records"
Cohesion: 0.03
Nodes (74): anyId, bytesCount, distinctByPreferredDifficulty, distinctByPreferredExplainMode, idBetween, idEqualTo, idGreaterThan, idLessThan (+66 more)

### Community 16 - "Scene Canvas Widget"
Cohesion: 0.03
Nodes (71): ../../domain/geometry/element_transformer.dart, ../../domain/geometry/scene_hit_test.dart, ../../domain/services/eraser_service.dart, ../../domain/services/pixel_eraser_service.dart, ../../domain/services/snap_engine.dart, HistoryController get, ../input/scene_pointer_listener.dart, _active (+63 more)

### Community 17 - "Home Note Card Widgets"
Cohesion: 0.03
Nodes (64): @immutable, ../../../../editor/render/scene_element_painter.dart, ImageProvider?, knowledge_graph_button.dart, controller, initial, showSceneTextDialog, AiCapabilities (+56 more)

### Community 18 - "Notebook Editor Screen"
Cohesion: 0.04
Nodes (60): Color get, editable_note_title.dart, ../../features/ai/presentation/sidebar/ai_sidebar.dart, ../../features/home/data/repositories/note_repository.dart, ../../features/summarize/presentation/summarize_notifier.dart, ../../features/summarize/presentation/widgets/summary_bottom_sheet.dart, ../import/fit_image_rect.dart, ../import/scene_import_service.dart (+52 more)

### Community 19 - "AI Context View"
Cohesion: 0.04
Nodes (59): ../../../ai/data/llm/llm_model_spec.dart, _PageNavBar, _CenteredMessage, _ConceptChip, confidence, context, _ContextBody, createState (+51 more)

### Community 20 - "Notes Screen And Providers"
Cohesion: 0.04
Nodes (59): ../../../editor/state/page_notifier.dart, editor/state/scene_controller.dart, ../../../../editor/state/scene_image_cache_provider.dart, ../home_notifier.dart, homeNotifierProvider, cards, elements, images (+51 more)

### Community 21 - "AI Riverpod Providers"
Cohesion: 0.04
Nodes (54): context_engine_notifier.dart, ../data/embeddings/local_text_embedder.dart, ../data/llm/cloud_llm_client.dart, ../data/ocr/image_text_recognition_service.dart, ../data/providers/cloud_gateway_provider.dart, ../data/providers/local_gemma_provider.dart, ../data/rag/note_chunk_store.dart, ../../../dev/dev_secrets.dart (+46 more)

### Community 22 - "Settings Screen"
Cohesion: 0.05
Nodes (51): ../../../ai/data/embeddings/embedder_adapter.dart, ../../../ai/data/embeddings/embedder_spec.dart, ConsumerState, ConsumerStatefulWidget, NotebookEditorScreen, embedderDownloadManagerProvider, huggingFaceTokenProvider, modelDownloadManagerProvider (+43 more)

### Community 23 - "Summarization Service"
Cohesion: 0.05
Nodes (47): ../../../ai/data/llm/cloud_llm_client.dart, ../../../ai/domain/ai_provider.dart, ../../../ai/domain/meaningfulness_gate.dart, ../../../ai/domain/page_content.dart, ../../../ai/domain/page_content_extractor.dart, ../../../ai/domain/text_budget.dart, ../../data/cache/summary_cache.dart, _chunkAndReduce (+39 more)

### Community 24 - "Gateway Rate Limiting"
Cohesion: 0.07
Nodes (30): Exception, RateLimiter, RateLimitExceededError, Per-anonymous-device daily caps: LLM token/request usage, and (Loop 3.4) Web…, Independent daily cap for the Web Search tool (Loop 3.4) — same device-key/day…, Raises [RateLimitExceededError] if [device_key] already used its daily search…, Raises [RateLimitExceededError] if [device_key] is already at its daily cap;…, SearchRateLimitConfig (+22 more)

### Community 25 - "Gateway Model Providers"
Cohesion: 0.09
Nodes (24): Protocol, Environment-driven configuration. Everything is read from process env vars…, Picks which `ModelProvider` serves a request. Kept separate from…, ChatTurn, ModelProvider, ProviderError, Exception, Common provider shape so routing never depends on a specific vendor SDK. Every… (+16 more)

### Community 26 - "Scene Element Domain Model"
Cohesion: 0.04
Nodes (44): element_style.dart, align, boundsRect, color, containerId, copyWith, edges, elbowed (+36 more)

### Community 27 - "App Color Constants"
Cohesion: 0.05
Nodes (43): accent, accentGreen, accentGreenWash, accentPurple, accentPurpleStrong, accentPurpleWash, accentRed, accentRedWash (+35 more)

### Community 28 - "Editor Control Bars"
Cohesion: 0.06
Nodes (38): ../../domain/geometry/element_bounds.dart, ../../../domain/services/alignment_service.dart, ../../../domain/services/library_service.dart, ../../../domain/services/z_order_service.dart, editor_controls_shared.dart, editor_library_sheet.dart, ../../../features/ai/data/ocr/image_text_recognition_service.dart, ../../../features/ai/presentation/ai_providers.dart (+30 more)

### Community 29 - "Anki Collection Export"
Cohesion: 0.05
Nodes (40): _, flashcard_csv.dart, AnkiCard, AnkiCollection, ankiFieldChecksum, ankiGuid, AnkiNote, ankiSchemaStatements (+32 more)

### Community 30 - "Handwriting Ink Lines"
Cohesion: 0.05
Nodes (40): b, band, bottom, bounds, current, _foldStrayMarks, fromLTRB, _groupBounds (+32 more)

### Community 31 - "Concept Mastery Domain"
Cohesion: 0.05
Nodes (40): afterQuiz, conceptKey, conceptKeysMentionedIn, ConceptMastery, conceptName, conceptsMentionedIn, copyWith, demoted (+32 more)

### Community 32 - "Quiz Sheet UI"
Cohesion: 0.05
Nodes (39): quizNotifierProvider, build, _check, _checked, _choice, concepts, controller, _correct (+31 more)

### Community 33 - "AI Ask View"
Cohesion: 0.06
Nodes (38): ../../data/embeddings/embedder_spec.dart, askNotesNotifierProvider, _actions, AiAskView, _AiAskViewState, _Answer, _body, build (+30 more)

### Community 34 - "Ask Notes Notifier"
Cohesion: 0.07
Nodes (37): ../data/embeddings/embedder_download_manager.dart, ../domain/features/notes_qa.dart, ../../domain/rag/rag_retriever.dart, ask, AskNotesAnswered, AskNotesAnswering, AskNotesComposing, AskNotesDownloadingModel (+29 more)

### Community 35 - "Summarize Notifier"
Cohesion: 0.06
Nodes (36): ../../ai/data/handwriting/handwriting_recognition_service.dart, ../../ai/data/llm/llm_exceptions.dart, ../../ai/data/llm/model_download_manager.dart, cancelModelDownload, chunked, cloudEnabled, downloadModelAndRetry, _downloads (+28 more)

### Community 36 - "Editor Tool Controller"
Cohesion: 0.05
Nodes (36): closePanel, color, copyWith, edges, elbowed, endArrowhead, eraserPixel, fillColor (+28 more)

### Community 37 - "Canvas Interaction Glue"
Cohesion: 0.10
Nodes (37): historyProvider, pageRepositoryProvider, sceneControllerProvider, sceneImageCacheProvider, selectionProvider, viewportProvider, EditorAppBarActions, _export (+29 more)

### Community 38 - "AI Research View"
Cohesion: 0.07
Nodes (35): researchNotifierProvider, _actions, AiResearchView, _AiResearchViewState, _Answer, _body, build, _Centered (+27 more)

### Community 39 - "Scene Element Painter"
Cohesion: 0.06
Nodes (34): dash_path.dart, ../../domain/geometry/scene_geometry.dart, Expando, _align, _arrowhead, _arrowheadSize, _closedPath, _dash (+26 more)

### Community 40 - "Flashcard Sheet UI"
Cohesion: 0.06
Nodes (34): ../../data/flashcards/flashcard_apkg.dart, ../../data/flashcards/flashcard_csv.dart, ../../../export/export_share_service.dart, flashcardNotifierProvider, build, card, _CardFace, cards (+26 more)

### Community 41 - "Explain Notifier"
Cohesion: 0.07
Nodes (34): ../data/llm/llm_exceptions.dart, ../../domain/routing/intelligent_router.dart, cancelCloud, cancelModelDownload, changeMode, confirmCloudAndRun, downloadModelAndRetry, _downloads (+26 more)

### Community 42 - "Quiz Notifier"
Cohesion: 0.07
Nodes (33): ../data/llm/model_download_manager.dart, ../../domain/features/quiz_generator.dart, ../domain/text_budget.dart, allowCoding, cancelModelDownload, concepts, count, downloadModelAndRetry (+25 more)

### Community 43 - "Study Planner Screen"
Cohesion: 0.07
Nodes (33): studyPlannerProvider, build, _canGenerate, _Centered, createState, day, _DayCard, _examDate (+25 more)

### Community 44 - "Flashcard Notifier"
Cohesion: 0.07
Nodes (32): ../data/flashcards/flashcard_store.dart, ../../domain/context_engine/page_context.dart, ../domain/features/flashcard_generator.dart, cancelModelDownload, cards, context, deckName, downloadModelAndRetry (+24 more)

### Community 45 - "Study Plan Domain"
Cohesion: 0.06
Nodes (32): completed, conceptCount, conceptName, copyWith, createdAt, date, days, examDate (+24 more)

### Community 46 - "Knowledge Graph Screen"
Cohesion: 0.06
Nodes (31): ../ai_providers.dart, ../../domain/knowledge_graph/graph_layout.dart, knowledgeGraphProvider, _at, build, color, createState, didUpdateWidget (+23 more)

### Community 47 - "Legacy Stroke Adapters"
Cohesion: 0.07
Nodes (29): legacy_models/imported_content.dart, legacy_models/shape_element.dart, legacy_models/stroke.dart, freehandFromStroke, fromShapeElement, imageFromImportedContent, key, LegacyAdapters (+21 more)

### Community 48 - "Learning Memory Repository"
Cohesion: 0.07
Nodes (30): concept_mastery_record.dart, concept_relation_record.dart, ../../domain/knowledge_graph/concept_relation.dart, ../../domain/memory/concept_mastery.dart, ../../domain/memory/learning_preferences.dart, ../../domain/memory/quiz_attempt.dart, ../../domain/memory/study_session.dart, learning_preferences_record.dart (+22 more)

### Community 49 - "Handwriting Recognition Service"
Cohesion: 0.06
Nodes (30): ../../../../data/migration/legacy_models/stroke.dart, DigitalInkRecognizerModelManager, ../../domain/handwriting/ink_lines.dart, ../../domain/recognition_result.dart, cause, deleteModel, dispose, elementsToInk (+22 more)

### Community 50 - "Quiz Generator"
Cohesion: 0.07
Nodes (30): _bool, _complete, correctAnswer, correctIndex, difficultyFor, explanation, fromJson, generate (+22 more)

### Community 51 - "Notebook Book View"
Cohesion: 0.07
Nodes (28): class, sceneElementStoreProvider, _BookPage, build, _byPage, _controller, count, createState (+20 more)

### Community 52 - "Context Engine Notifier"
Cohesion: 0.07
Nodes (28): ../domain/context_engine/context_engine.dart, ../domain/page_content_extractor.dart, _analyzeIfChanged, _cache, debounce, dispose, _elements, _engine (+20 more)

### Community 53 - "Page Context And Preferences"
Cohesion: 0.07
Nodes (27): ../features/explainer.dart, ../knowledge_graph/concept_relation.dart, confidence, currentTopic, definitions, empty, estimatedLevel, fromJson (+19 more)

### Community 54 - "Viewport Controller"
Cohesion: 0.07
Nodes (28): autoFitMinZoom, configure, _constrain, copyWith, infiniteMaxZoom, infiniteMinZoom, _maxZoom, _minZoom (+20 more)

### Community 55 - "Scene Domain Services"
Cohesion: 0.08
Nodes (24): ../geometry/element_transformer.dart, ../geometry/scene_geometry.dart, align, AlignEdge, AlignmentService, _delta, distribute, SceneAxis (+16 more)

### Community 56 - "Settings Provider"
Cohesion: 0.07
Nodes (27): cloudAiEnabled, CloudPrivacy, copyWith, darkMode, devMode, exportDefault, hasHuggingFaceToken, hasSeenFirstCloudCall (+19 more)

### Community 57 - "AI Tool Implementations"
Cohesion: 0.08
Nodes (25): Dio, CalculatorTool, Tool, _baseUrl, description, _deviceKey, _dio, execute (+17 more)

### Community 58 - "Scene Pointer Input"
Cohesion: 0.08
Nodes (26): _activePointers, _activeStylusPointers, build, child, createState, _emitViewportUpdate, enablePalmRejection, _extractPoint (+18 more)

### Community 59 - "Intelligent Model Router"
Cohesion: 0.09
Nodes (25): ../../../../core/providers/settings_provider.dart, AiProvider, capabilities, cloudFrontier, cloudMid, CloudRouteDecision, CloudTier, decide (+17 more)

### Community 60 - "Gemma LLM Adapter"
Cohesion: 0.09
Nodes (25): InferenceModel, InferenceModelSession, addTurn, close, ensureInitialized, FlutterGemmaInstaller, FlutterGemmaRuntime, GemmaBootstrap (+17 more)

### Community 61 - "Notes Color Palette"
Cohesion: 0.08
Nodes (25): accent, background, card, cardGap, cardHeight, cardHeightMax, cardHeightMin, cardRadius (+17 more)

### Community 62 - "Gateway Endpoint Tests"
Cohesion: 0.15
Nodes (21): RateLimitConfig, client(), _FakeProvider, _FakeToolProvider, _fresh_rate_limiter(), asyncio, fixture, Duck-types `ModelProvider` without any real SDK/network call. (+13 more)

### Community 63 - "Tool Options Overlay"
Cohesion: 0.09
Nodes (22): IconData, displayName, iconData, EditorToolController, EditorToolState, anchorBottom, ctl, _EraserPanel (+14 more)

### Community 64 - "Provider Selection Tests"
Cohesion: 0.15
Nodes (16): Settings, Exception, Chooses a provider for [model_tier], honoring [provider_hint] when given. A…, select_provider(), UnknownModelTierError, Model Tier Routing, Gemma Cloud Tier Fallback, Provider-selection logic — the thing that actually needs coverage, per the… (+8 more)

### Community 65 - "Research Notifier"
Cohesion: 0.09
Nodes (22): Completer, ask, cancelCloud, _cancelInFlight, _completer, confirmCloudAndAsk, dispose, isFirstEver (+14 more)

### Community 66 - "Note Chunk And Summary Store"
Cohesion: 0.09
Nodes (21): dart:convert, contentSignature, embeddedAt, embedding, embeddingModelId, fromDraft, id, notebookId (+13 more)

### Community 67 - "Page Chunker"
Cohesion: 0.09
Nodes (22): bodies, bodyBudget, chunkPage, chunks, ChunkSourceRef, kChunkOverlapWords, kChunkWords, _lastWords (+14 more)

### Community 68 - "Gateway Generate Router"
Cohesion: 0.18
Nodes (19): get_settings(), log_request(), Structured, content-free request logging. Per the Phase 3 privacy model:…, Tiny helper so call sites don't hand-roll `time.perf_counter()` math., RequestLogEntry, Stopwatch, _estimate_tokens(), generate() (+11 more)

### Community 69 - "Selection Controller And Router"
Cohesion: 0.09
Nodes (20): ../editor/ui/notebook_book_view_screen.dart, ../editor/ui/notebook_editor_screen.dart, ../editor/ui/scene_editor_screen.dart, ../features/ai/presentation/knowledge_graph/knowledge_graph_screen.dart, ../features/ai/presentation/study_planner/study_planner_screen.dart, ../features/home/presentation/screens/notes_screen.dart, ../features/settings/presentation/screens/about_screen.dart, ../features/settings/presentation/screens/settings_screen.dart (+12 more)

### Community 70 - "Scene Geometry And Hit Test"
Cohesion: 0.10
Nodes (19): element_bounds.dart, geometry_utils.dart, _mapGeometry, _mapPairs, rotateAbout, scaleAbout, SceneTransformer, translate (+11 more)

### Community 71 - "Pixel Eraser Service"
Cohesion: 0.09
Nodes (21): ../geometry/shape_geometry.dart, added, _densifyOffsets, _densifyPoints, _ellipsePoints, erase, _eraseFreehand, _eraseShape (+13 more)

### Community 72 - "Editor Bottom Bar"
Cohesion: 0.10
Nodes (21): EditorTool, editorToolProvider, _ArrowToolButton, build, EditorBottomBar, icon, onImport, onTap (+13 more)

### Community 73 - "Scene Render Layers"
Cohesion: 0.10
Nodes (19): CustomPainter, ../../domain/services/frame_service.dart, BackgroundLayer, SceneLaserLayer, element, paint, ScenePreviewLayer, shouldRepaint (+11 more)

### Community 74 - "PDF Import Service"
Cohesion: 0.10
Nodes (20): ../../data/migration/legacy_models/imported_content.dart, docsDir, document, filePath, _fnv1aHashHex, hash, importedPages, ImportException (+12 more)

### Community 75 - "Scene Exporter"
Cohesion: 0.10
Nodes (20): ../../domain/geometry/selection_bounds.dart, ../../domain/geometry/shape_geometry.dart, _alpha, contentBounds, defaultPadding, _esc, _hex, _n (+12 more)

### Community 76 - "Page Content Extractor"
Cohesion: 0.10
Nodes (19): ../data/handwriting/handwriting_recognition_service.dart, ../data/ocr/gemma_vision_ocr_service.dart, HandwritingRecognitionService, _extractFrom, extractPage, extractSelection, ImageBytesLoader, ImageTextReader (+11 more)

### Community 77 - "Model Download Manager"
Cohesion: 0.10
Nodes (19): device_storage.dart, gemma_adapter.dart, cancelDownload, _cancelToken, delete, dispose, download, _inFlight (+11 more)

### Community 78 - "Embedder Adapter"
Cohesion: 0.12
Nodes (19): ../domain/rag/text_embedder.dart, EmbeddingModel, close, embedAll, EmbedderInstaller, EmbeddingRuntime, EmbeddingSession, FlutterGemmaEmbedderInstaller (+11 more)

### Community 79 - "Shared UI Widgets"
Cohesion: 0.14
Nodes (20): EditableNoteTitle, _EditableNoteTitleState, _BackgroundSheet, _BackgroundSheetState, _Deck, _DeckState, _GraphView, _GraphViewState (+12 more)

### Community 80 - "Writing Assistant"
Cohesion: 0.11
Nodes (19): _complete, confidence, excerpt, fromJson, kind, label, maxSuggestions, message (+11 more)

### Community 81 - "Calculator Tool"
Cohesion: 0.10
Nodes (19): _CalculatorError, _CalculatorParser, description, execute, _expression, _format, _isDigit, _maxExpressionLength (+11 more)

### Community 82 - "Embedder Download Manager"
Cohesion: 0.11
Nodes (18): CancelToken?, cancelDownload, _cancelToken, delete, dispose, download, EmbedderDownloadManager, _inFlight (+10 more)

### Community 83 - "Knowledge Graph Domain"
Cohesion: 0.11
Nodes (18): concept_relation.dart, build, degree, edges, empty, fromKey, GraphEdge, GraphNode (+10 more)

### Community 84 - "Scene Import Service"
Cohesion: 0.11
Nodes (18): ../../core/constants/storage_paths.dart, ../../features/import/pdf_service.dart, ImagePicker, _compressAndSave, ImportedImage, importPdf, importPhoto, kMaxImportedImageEdge (+10 more)

### Community 85 - "RAG Index Scheduler"
Cohesion: 0.11
Nodes (17): dart:async, ../domain/rag/rag_indexer.dart, _embedder, indexPage, RagIndexer, RagIndexOutcome, dispose, idleDelay (+9 more)

### Community 86 - "Scene Controller"
Cohesion: 0.11
Nodes (18): ../../data/persistence/isar_scene_element_store.dart, add, addMany, appDocsPathProvider, applyAdd, applyRemove, applyReplaceAll, applyUpdate (+10 more)

### Community 87 - "Scene Element Codec"
Cohesion: 0.11
Nodes (16): ../../../../domain/model/scene_element.dart, _d, decode, decodeList, _doubles, encode, encodeList, _points (+8 more)

### Community 88 - "OCR Layout"
Cohesion: 0.11
Nodes (18): byHeight, byWidth, estimateTextWidth, _fontSizeFor, kOcrFontHeightRatio, kOcrLineHeightRatio, kOcrMinFontSize, layOutOcrBoxes (+10 more)

### Community 89 - "Note Card Data"
Cohesion: 0.11
Nodes (18): createdAt, fromNotebook, id, _looksLikeChecklist, _markerPattern, matches, NoteType, pageLabel (+10 more)

### Community 90 - "App Entry Point"
Cohesion: 0.11
Nodes (17): app/app.dart, data/migration/launch_migration.dart, data/persistence/scene_element_record.dart, editor/state/library_controller.dart, features/ai/data/flashcards/flashcard_record.dart, features/ai/data/memory/concept_mastery_record.dart, features/ai/data/memory/concept_relation_record.dart, features/ai/data/memory/learning_preferences_record.dart (+9 more)

### Community 91 - "Color Palette And Download UI"
Cohesion: 0.12
Nodes (16): core/constants/app_colors.dart, ../../core/constants/editor_constants.dart, build, color, createState, onTap, _open, selected (+8 more)

### Community 92 - "Quiz Attempt Domain"
Cohesion: 0.12
Nodes (16): concept_mastery.dart, attemptId, conceptKeys, conceptOutcomes, correct, correctCount, notebookId, outcomes (+8 more)

### Community 93 - "Path Geometry Utils"
Cohesion: 0.13
Nodes (14): dart:math, dart:ui, ../../../../domain/model/stroke_point.dart, GeometryUtils, pointInPolygon, pointToSegmentDistance, rectsIntersect, rotatePoint (+6 more)

### Community 94 - "Flashcard And Library Models"
Cohesion: 0.12
Nodes (15): DateTime, copyWith, createdAt, elements, id, LibraryItem, name, back (+7 more)

### Community 95 - "Graph Layout"
Cohesion: 0.12
Nodes (16): double get, knowledge_graph.dart, clampUnit, computeGraphLayout, h, iterations, k, length (+8 more)

### Community 96 - "AI Capabilities And Migration"
Cohesion: 0.12
Nodes (15): legacy_page_source.dart, runLaunchMigration, approxCostPerCallUsd, contextWindowTokens, displayName, isLocal, modelId, supportsEmbeddings (+7 more)

### Community 97 - "Scene Commands"
Cohesion: 0.15
Nodes (16): added, AddElementsCommand, after, apply, applyAdd, applyRemove, applyReplaceAll, applyUpdate (+8 more)

### Community 98 - "AI Message Model"
Cohesion: 0.12
Nodes (16): AiMessage, AiRole, assistant, content, copyWith, fromMap, hashCode, operator (+8 more)

### Community 99 - "Anki APKG Export"
Cohesion: 0.12
Nodes (15): anki_collection.dart, archive, _buildCollectionDb, db, dbBytes, _dbEntryName, dir, flashcardsToApkg (+7 more)

### Community 100 - "PNG Size Utils"
Cohesion: 0.16
Nodes (15): AsyncValue, SceneMutator, height, pngPixelSize, _pngSignature, _uint32, width, LibraryController (+7 more)

### Community 101 - "Clipboard And Device Storage"
Cohesion: 0.12
Nodes (14): ../../data/persistence/scene_element_codec.dart, ../../../domain/services/selection_editing.dart, ClipboardService, copy, encode, paste, pasteTransform, tryDecode (+6 more)

### Community 102 - "Gemma Vision OCR"
Cohesion: 0.12
Nodes (15): ../../domain/ai_exception.dart, ../domain/image_transcriber.dart, ../../domain/meaningfulness_gate.dart, attempts, empty, _gate, GemmaOcrResult, GemmaVisionOcrService (+7 more)

### Community 103 - "History Controller"
Cohesion: 0.13
Nodes (15): ../../domain/commands/scene_command.dart, canRedo, canUndo, clear, HistoryController, HistoryState, _mutator, push (+7 more)

### Community 104 - "Writing Assistant Notifier"
Cohesion: 0.12
Nodes (15): ../domain/features/writing_assistant.dart, ../domain/page_content.dart, WritingAssistant, _assistant, _cache, dismiss, _entries, _lastSignature (+7 more)

### Community 105 - "Template Config"
Cohesion: 0.12
Nodes (15): dotRadius, dotSpacing, forBackground, forDark, forLight, lineColor, lineSpacing, lineWidth (+7 more)

### Community 106 - "LLM Model Spec"
Cohesion: 0.12
Nodes (15): active, approxSizeBytes, authToken, displayName, downloadUrl, filename, fileType, gemma4E2B (+7 more)

### Community 107 - "Local Gemma Provider"
Cohesion: 0.12
Nodes (15): _applyStopSequences, capabilities, embed, _embedder, _firstStopIndex, generate, interChunkTimeout, _lock (+7 more)

### Community 108 - "Researcher Feature"
Cohesion: 0.16
Nodes (15): _client, generateWithTools, maxToolHops, research, Researcher, ResearchEvent, ResearchTextChunk, ResearchToolUsed (+7 more)

### Community 109 - "Page Content Model"
Cohesion: 0.12
Nodes (15): bounds, combinedText, empty, hasText, hasUnrecognizedImages, inkTopScore, kind, needsOcr (+7 more)

### Community 110 - "Search Bar Widget"
Cohesion: 0.13
Nodes (15): build, _clear, controller, createState, dispose, _handleChanged, _hasText, hintText (+7 more)

### Community 111 - "Scene Element Store"
Cohesion: 0.14
Nodes (13): app_colors.dart, ../../editor/state/editor_tool_controller.dart, kArrowheadIcons, kFavoritePickerColors, kFontFamilies, IsarSceneElementStore, _byPage, clearForPage (+5 more)

### Community 112 - "Scene Editor Screen"
Cohesion: 0.13
Nodes (13): controls/editor_app_bar_actions.dart, controls/editor_bottom_bar.dart, controls/editor_tool_options_overlay.dart, ../../data/persistence/scene_element_store.dart, build, _demoKey, _SceneEditorBody, SceneEditorScreen (+5 more)

### Community 113 - "Cloud Gateway Provider"
Cohesion: 0.13
Nodes (14): ../domain/features/researcher.dart, ../domain/tools/tool.dart, ../../domain/tools/tool_generation_event.dart, _capabilities, _dio, embed, generate, generateWithTools (+6 more)

### Community 114 - "Page Notifier"
Cohesion: 0.14
Nodes (14): ../../features/home/data/repositories/page_repository.dart, copyWith, currentPageIndex, deletePage, duplicatePage, initialize, insertPage, _notebookId (+6 more)

### Community 115 - "Library Repository"
Cohesion: 0.15
Nodes (14): File, decode, decodeItem, encode, encodeItem, file, FileLibraryRepository, InMemoryLibraryRepository (+6 more)

### Community 116 - "Embedder Spec"
Cohesion: 0.13
Nodes (14): active, approxSizeBytes, _basename, dimensions, displayName, EmbedderSpec, embeddingGemma300m, modelFilename (+6 more)

### Community 117 - "RAG Retriever"
Cohesion: 0.13
Nodes (14): LocalTextEmbedder, NoteChunk, chunk, _embedder, kMinRelevance, kRetrievalTopK, RagRetriever, RetrievedChunk (+6 more)

### Community 118 - "Image Text Recognition"
Cohesion: 0.13
Nodes (14): _cache, cause, dispose, ImageTextRecognitionService, lines, message, readText, RecognizedLine (+6 more)

### Community 119 - "AI Router"
Cohesion: 0.13
Nodes (14): AiRoute, decide, inputWordBudgetFor, isOnline, localCapabilities, localInputWordBudget, Reachability, responseReserveTokens (+6 more)

### Community 120 - "Explainer Feature"
Cohesion: 0.14
Nodes (14): _base, content, explain, Explainer, ExplainInput, ExplainMode, ExplainModeLabel, label (+6 more)

### Community 121 - "Concept Relation Domain"
Cohesion: 0.13
Nodes (14): ConceptRelation, confidence, fromKey, fromName, hashCode, isValid, operator, parseList (+6 more)

### Community 122 - "Text Budget"
Cohesion: 0.13
Nodes (14): append, _blankLine, chunkByWords, chunks, countWords, current, currentWords, flush (+6 more)

### Community 123 - "Gateway Search Tool Tests"
Cohesion: 0.27
Nodes (13): client(), _configured_settings(), _fake_search_exa(), _fake_search_exa_error(), asyncio, fixture, Tests for POST /v1/tools/search (Loop 3.4 Web Search tool proxy)., test_search_503_when_unconfigured() (+5 more)

### Community 124 - "Scene Export And Transcribe"
Cohesion: 0.14
Nodes (12): ai_exception.dart, dart:typed_data, ../../../../editor/render/scene_exporter.dart, ../../editor/render/scene_image_cache.dart, export_share_service.dart, LocalGemmaProvider, ImageTranscriber, transcribeImage (+4 more)

### Community 125 - "Isar Record Schemas"
Cohesion: 0.14
Nodes (14): GetAppMetaCollection, GetSceneElementRecordCollection, GetFlashcardRecordCollection, GetConceptMasteryRecordCollection, GetConceptRelationRecordCollection, GetLearningPreferencesRecordCollection, GetQuizAttemptRecordCollection, GetStudySessionRecordCollection (+6 more)

### Community 126 - "Selection Overlay Layer"
Cohesion: 0.14
Nodes (13): CustomClipper, accent, boxScreen, handleScreen, kHandleHitRadius, kHandleSize, kRotateGap, marqueeScreen (+5 more)

### Community 127 - "Editable Note Title"
Cohesion: 0.14
Nodes (13): FocusNode, build, _commit, _controller, createState, didUpdateWidget, dispose, _editing (+5 more)

### Community 128 - "AI Generation Options"
Cohesion: 0.14
Nodes (13): int get, copyWith, hashCode, maxTokens, operator, precise, seed, stopSequences (+5 more)

### Community 129 - "Record Serialization Glue"
Cohesion: 0.14
Nodes (14): AppMeta, SceneElementRecord, collection, FlashcardRecord, ConceptMasteryRecord, ConceptRelationRecord, LearningPreferencesRecord, QuizAttemptRecord (+6 more)

### Community 130 - "Selection Bounds"
Cohesion: 0.14
Nodes (13): _affectsX, _affectsY, anchor, anchorFor, handlePoint, handlePoints, HandlePos, resize (+5 more)

### Community 131 - "Background Layer"
Cohesion: 0.14
Nodes (13): TemplateType, backgroundColor, deskColor, pageRect, paint, _paintInfinite, _paintPage, scrollX (+5 more)

### Community 132 - "Fit Image Rect"
Cohesion: 0.14
Nodes (13): area, capped, fitCentred, fraction, fromCenter, fromLTWH, inlinePlacement, inlineSize (+5 more)

### Community 133 - "LLM Exceptions"
Cohesion: 0.21
Nodes (13): EmbedderTokenRequiredException, availableBytes, cause, InsufficientStorageException, LlmException, LlmGenerationException, LlmNotReadyException, LlmTimeoutException (+5 more)

### Community 134 - "Study Scheduler"
Cohesion: 0.14
Nodes (13): addAll, buckets, buildStudyPlan, capacity, maxTasksPerDay, numDays, scheduled, seen (+5 more)

### Community 135 - "Scene Image Cache"
Cohesion: 0.15
Nodes (12): ../../data/persistence/ref_counted_cache.dart, Image, baseDir, _cache, decode, _defaultReadBytes, dispose, ensure (+4 more)

### Community 136 - "Local Text Embedder"
Cohesion: 0.15
Nodes (12): ../../domain/ai_provider.dart, embedder_adapter.dart, embedder_spec.dart, dimensions, embedAll, embedOne, _lock, modelId (+4 more)

### Community 137 - "Flashcard CSV Export"
Cohesion: 0.15
Nodes (12): body, buffer, cards, cleaned, directives, _escape, flashcardsToAnkiCsv, flashcardsToCsv (+4 more)

### Community 138 - "Context Engine"
Cohesion: 0.15
Nodes (12): analyze, _buildPrompt, _complete, ContextEngine, _gate, _matchingBrace, _provider, _retryNudge (+4 more)

### Community 139 - "Meaningfulness Gate"
Cohesion: 0.15
Nodes (12): evaluate, fail, failure, GateFailure, _letter, maxAvgScore, MeaningfulnessGate, minAlphaRatio (+4 more)

### Community 140 - "Vector Math"
Cohesion: 0.15
Nodes (12): clamp, cosineSimilarity, dot, item, minScore, normA, normB, score (+4 more)

### Community 141 - "Flashcard Generator"
Cohesion: 0.17
Nodes (11): ../ai_router.dart, ../context_engine/context_engine.dart, ../context_engine/page_context.dart, _complete, FlashcardGenerator, generate, maxCards, _provider (+3 more)

### Community 142 - "Laser Pointer Layer"
Cohesion: 0.17
Nodes (11): Color, addedMs, color, fadeMs, LaserPoint, nowMs, paint, points (+3 more)

### Community 143 - "Study Planner Notifier"
Cohesion: 0.17
Nodes (11): ../data/memory/learning_memory_repository.dart, ../data/study_planner/study_plan_store.dart, ../domain/knowledge_graph/knowledge_graph.dart, ../domain/study_planner/study_scheduler.dart, clear, generate, _load, _memory (+3 more)

### Community 144 - "Study Session Domain"
Cohesion: 0.17
Nodes (11): DateTime get, Duration, duration, endedAt, featuresUsed, notebookId, record, sessionId (+3 more)

### Community 145 - "Note Repository"
Cohesion: 0.17
Nodes (11): ../../domain/models/note_page.dart, createNotebook, deleteNotebook, getAllNotebooks, getNotebook, _isar, updateBackgroundColor, updateLayoutMode (+3 more)

### Community 146 - "Recognition Result"
Cohesion: 0.17
Nodes (11): double?, GateResult, empty, gate, hasInk, PageRecognition, pages, RecognitionOutcome (+3 more)

### Community 147 - "Stroke Point Model"
Cohesion: 0.17
Nodes (11): int?, copyWith, fromMap, pressure, simulatePressure, StrokePoint, t, toMap (+3 more)

### Community 148 - "Ref Counted Cache"
Cohesion: 0.17
Nodes (11): acquire, contains, count, disposeAll, _entries, _Entry, refCount, RefCountedCache (+3 more)

### Community 149 - "Shape Geometry"
Cohesion: 0.17
Nodes (11): angleBetween, boundingRect, centroid, isClosed, linearR2, lineFromGeometry, _perpendicularDistance, rdpSimplify (+3 more)

### Community 150 - "Cloud LLM Client"
Cohesion: 0.18
Nodes (11): chatCompletion, ChatMessage, CloudLlmClient, CloudUnavailableException, content, message, role, StubCloudLlmClient (+3 more)

### Community 151 - "Page Repository"
Cohesion: 0.17
Nodes (11): createPage, deletePage, _enforceContiguity, getPagesForNotebook, _isar, loadPage, movePage, PageRepository (+3 more)

### Community 152 - "Notes QA Feature"
Cohesion: 0.18
Nodes (10): ../ai_provider.dart, answer, findSources, _formatPassages, NotesQa, notFoundReply, _provider, _retriever (+2 more)

### Community 153 - "Home Notifier"
Cohesion: 0.18
Nodes (10): ../data/repositories/note_repository.dart, ../../domain/models/notebook.dart, NoteRepository, createNotebook, deleteNotebook, loadNotebooks, noteRepositoryProvider, notifier (+2 more)

### Community 154 - "Template Painter"
Cohesion: 0.18
Nodes (10): ../../domain/model/template_config.dart, ../../../../domain/model/template_type.dart, _minOnScreenSpacing, paint, _paintDotted, _paintEngineeringGrid, _paintGrid, _paintRuled (+2 more)

### Community 155 - "Snap Engine"
Cohesion: 0.18
Nodes (10): a, adjust, b, guides, none, snap, SnapEngine, SnapGuide (+2 more)

### Community 156 - "Tool Interface"
Cohesion: 0.18
Nodes (10): content, description, error, execute, name, ok, parameterSchema, success (+2 more)

### Community 157 - "Summarize Providers"
Cohesion: 0.20
Nodes (9): ../../ai/domain/ai_router.dart, ../../ai/presentation/ai_providers.dart, ../data/cache/summary_store.dart, ../domain/services/summarization_service.dart, AiRouter, SummarizationService, aiRouterProvider, downloads (+1 more)

### Community 158 - "Autosave Controller"
Cohesion: 0.20
Nodes (9): bool get, AutosaveController, debounce, dispose, flush, hasPending, schedule, _timer (+1 more)

### Community 159 - "Study Plan Store"
Cohesion: 0.22
Nodes (9): ../domain/study_planner/study_plan.dart, IsarCollection, deleteForNotebook, IsarStudyPlanStore, loadForNotebook, _plans, save, StudyPlanStore (+1 more)

### Community 160 - "Scene Migrator"
Cohesion: 0.20
Nodes (9): legacy_adapters.dart, gate, run, SceneMigratorV2, source, store, targetVersion, ../persistence/scene_element_store.dart (+1 more)

### Community 161 - "Legacy Ink File Storage"
Cohesion: 0.20
Nodes (9): deleteNotebookInkFiles, deletePageInkFile, InkFileStorage, loadStrokes, _notebookDir, _pageFilePath, saveStrokes, saveStrokesSync (+1 more)

### Community 162 - "Migration Gate"
Cohesion: 0.24
Nodes (9): currentVersion, InMemoryMigrationGate, _isar, IsarMigrationGate, MigrationGate, setVersion, _version, ../persistence/scene_element_record.dart (+1 more)

### Community 163 - "Tool Generation Events"
Cohesion: 0.27
Nodes (9): CloudGatewayProvider, ToolCallingClient, arguments, callId, name, text, ToolCallRequested, ToolGenerationEvent (+1 more)

### Community 164 - "AI Exceptions"
Cohesion: 0.29
Nodes (9): AiException, AiGenerationException, AiModelNotReadyException, AiUnavailableException, AiUnsupportedOperationException, cause, message, toString (+1 more)

### Community 165 - "App Theme"
Cohesion: 0.22
Nodes (8): ../constants/app_colors.dart, AppTheme, _bodyFont, _buildTextTheme, darkTheme, _displayFont, static const String, static ThemeData get

### Community 166 - "Export Share Service"
Cohesion: 0.22
Nodes (8): dart:io, ExportShareService, saveToDocuments, shareFile, sharePdf, sharePng, package:path_provider/path_provider.dart, package:share_plus/share_plus.dart

### Community 167 - "Library Controller"
Cohesion: 0.22
Nodes (8): data/persistence/library_repository.dart, ../../../domain/model/library_item.dart, addFromElements, libraryRepositoryProvider, load, remove, rename, _repo

### Community 168 - "Note Chunk Store"
Cohesion: 0.25
Nodes (8): ../../domain/rag/note_chunk.dart, deleteForPage, forNotebook, indexStateForPage, IsarNoteChunkStore, NoteChunkStore, replaceForPage, note_chunk_record.dart

### Community 169 - "Legacy Page Source"
Cohesion: 0.25
Nodes (8): features/home/domain/models/note_page.dart, features/home/domain/models/notebook.dart, legacy_models/ink_file_storage.dart, legacy_page_data.dart, _isar, IsarLegacyPageSource, LegacyPageSource, loadAllPages

### Community 170 - "Active Stroke Layer"
Cohesion: 0.22
Nodes (8): freehand_path.dart, color, opacity, paint, points, SceneActiveStrokeLayer, shouldRepaint, size

### Community 171 - "Gateway App And Docs"
Cohesion: 0.25
Nodes (8): get, health(), InkFlow AI Gateway — a minimal, stateless router to cloud-tier models. Scope…, InkFlow AI Gateway, X-Device-Key Header, Render Blueprint Deployment, Stateless Privacy Model, FastAPI Dependency

### Community 172 - "Isar Scene Element Store"
Cohesion: 0.22
Nodes (8): Isar get, clearForPage, _isar, loadForPage, upsertForPage, scene_element_record.dart, scene_element_record_mapper.dart, scene_element_store.dart

### Community 173 - "Z Order Service"
Cohesion: 0.22
Nodes (8): bringForward, bringToFront, _reindex, sendBackward, sendToBack, _sorted, withZOrder, ZOrderService

### Community 174 - "Rough Renderer"
Cohesion: 0.22
Nodes (8): crossHatch, ellipsePolygon, hachure, _lines, outline, _r, _roughLine, RoughRenderer

### Community 175 - "Research Notifier Extras"
Cohesion: 0.22
Nodes (9): ResearchComposing, ResearchConfirmCloud, ResearchError, ResearchIdle, ResearchNotifier, ResearchReady, ResearchState, ResearchStreaming (+1 more)

### Community 176 - "AI Provider Interface"
Cohesion: 0.25
Nodes (7): ai_capabilities.dart, ai_generation_options.dart, ../ai_message.dart, AiCapabilities get, capabilities, embed, generate

### Community 177 - "Flashcard Store"
Cohesion: 0.29
Nodes (7): ../../domain/models/flashcard.dart, flashcard_record.dart, FlashcardStore, forNotebook, forPage, IsarFlashcardStore, replaceForPage

### Community 178 - "Element Bounds"
Cohesion: 0.25
Nodes (7): _boundsOfFlatPairs, _boundsOfPoints, ElementBounds, normalized, of, _rectFromLTRB, _shapeBounds

### Community 179 - "Scene Image Cache Provider"
Cohesion: 0.29
Nodes (6): ChangeNotifier, SceneImageCache, cache, ../render/scene_image_cache.dart, return, scene_controller.dart

### Community 180 - "About Screen"
Cohesion: 0.29
Nodes (6): Future, build, createState, _packageInfo, package:package_info_plus/package_info_plus.dart, PackageInfo

### Community 181 - "Library Service"
Cohesion: 0.29
Nodes (6): ../geometry/selection_bounds.dart, instantiate, LibraryService, ../model/library_item.dart, selection_editing.dart, z_order_service.dart

### Community 182 - "Storage Path Constants"
Cohesion: 0.29
Nodes (6): getFreeImageCacheRelativePath, getInkFilePath, getNotebookDir, getPdfPageCacheRelativePath, getThumbnailPath, StoragePaths

### Community 183 - "Text Embedder Interface"
Cohesion: 0.29
Nodes (6): dimensions, embedAll, embedOne, EmbedTaskType, modelId, String get

### Community 184 - "Cross Record References"
Cohesion: 0.33
Nodes (6): @embedded, ImportedContent, ShapeElement, QuizQuestionOutcomeRecord, StudyDayRecord, StudyTaskRecord

### Community 185 - "Note Scene Preview"
Cohesion: 0.33
Nodes (6): @visibleForTesting, trimShaftForHeads, placeNoteSlot, NoteScenePreviewPainter, scaleFor, pdfContentHashHex

### Community 186 - "Element Style Model"
Cohesion: 0.33
Nodes (5): Arrowhead, EdgeStyle, FillStyle, StrokeStyle, TextAlignKind

### Community 187 - "Scene Element Variants"
Cohesion: 0.33
Nodes (6): FrameElement, FreehandElement, ImageElement, SceneElement, SceneShapeElement, TextElement

### Community 188 - "Isar Service"
Cohesion: 0.33
Nodes (5): _isar, IsarService, openDatabase, package:isar/isar.dart, static Isar?

### Community 189 - "Stable ID Generation"
Cohesion: 0.40
Nodes (4): bytes, map, newStableId, random

## Knowledge Gaps
- **4285 isolated node(s):** `appRouter`, `routerProvider`, `AppColors`, `background`, `surface` (+4280 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `_FakeToolProvider` connect `Gateway Endpoint Tests` to `Gateway Rate Limiting`, `Gateway Model Providers`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Why does `RateLimiter` connect `Gateway Rate Limiting` to `Gateway App And Docs`, `Gateway Generate Router`, `Gateway Endpoint Tests`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Why does `RateLimitConfig` connect `Gateway Endpoint Tests` to `Gateway Rate Limiting`, `Gateway Generate Router`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **What connects `appRouter`, `routerProvider`, `AppColors` to the rest of the system?**
  _4285 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Scene Element Persistence Records` be split into smaller, more focused modules?**
  _Cohesion score 0.0038535645472061657 - nodes in this community are weakly interconnected._
- **Should `Concept Mastery Records` be split into smaller, more focused modules?**
  _Cohesion score 0.012658227848101266 - nodes in this community are weakly interconnected._
- **Should `Legacy Shape Element Models` be split into smaller, more focused modules?**
  _Cohesion score 0.013157894736842105 - nodes in this community are weakly interconnected._