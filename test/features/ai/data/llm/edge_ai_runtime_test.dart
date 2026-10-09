// The decisions EdgeAiRuntime makes around the plugin — which backend to
// ask for, whether multi-token prediction is worth enabling, when a loaded
// engine must be rebuilt. The plugin itself needs a device, so these run
// against fakes injected through the runtime's three seams; the harness below
// reproduces the one plugin behaviour the logic depends on: its Android cache
// is keyed on the model NAME only, so a second request silently receives the
// first instance whatever parameters it carries.

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/ai/data/llm/gemma_adapter.dart';
import 'package:inkflow/features/ai/data/llm/llm_exceptions.dart';
import 'package:inkflow/features/ai/data/llm/llm_model_spec.dart';
import 'package:inkflow/features/ai/domain/compute_backend.dart';
import 'package:inkflow/features/ai/domain/device_state.dart';

class _FakeInferenceSession implements InferenceModelSession {
  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeModel implements InferenceModel {
  _FakeModel(this.backend);

  final PreferredBackend? backend;
  bool closed = false;
  Map<Symbol, dynamic>? lastSessionArgs;

  @override
  PreferredBackend? get activeBackend => backend;

  @override
  Future<void> close() async => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #createSession) {
      lastSessionArgs = invocation.namedArguments;
      return Future<InferenceModelSession>.value(_FakeInferenceSession());
    }
    return super.noSuchMethod(invocation);
  }
}

class _Harness {
  _Harness({
    this.gpuWorks = true,
    this.reportsBackend = true,
    this.installed = true,
    this.gpuThrows = false,
    this.cpuThrows = false,
    this.notReady = false,
  }) {
    runtime = EdgeAiRuntime(
      ensureReady: (_) async {
        if (!installed) throw LlmNotReadyException();
      },
      loadModel: _load,
      now: () => clock,
      closeCachedModel: () async {
        if (models.isNotEmpty) await models.last.close();
      },
    );
  }

  DateTime clock = DateTime(2026, 10, 12, 10);

  /// Whether the plugin can actually bring the GPU up. When it can't it falls
  /// back to the CPU on its own, which is exactly the silent failure under test.
  final bool gpuWorks;
  final bool reportsBackend;
  final bool installed;

  /// The plugin THROWS on a GPU request — a delegate that cannot prepare part of
  /// the model fails the whole load instead of quietly falling back.
  final bool gpuThrows;
  final bool cpuThrows;

  /// The plugin says there is no active model (a StateError).
  final bool notReady;

  late final EdgeAiRuntime runtime;
  final loads = <GemmaLoadRequest>[];
  final models = <_FakeModel>[];

  Future<InferenceModel> _load(GemmaLoadRequest request) async {
    loads.add(request);
    if (notReady) throw StateError('No active inference model set.');
    if (request.preferredBackend == PreferredBackend.gpu && gpuThrows) {
      throw Exception('GPU engine could not be created');
    }
    if (request.preferredBackend == PreferredBackend.cpu && cpuThrows) {
      throw Exception('CPU engine could not be created');
    }
    if (models.isNotEmpty && !models.last.closed) return models.last;
    final onGpu = request.preferredBackend == PreferredBackend.gpu && gpuWorks;
    final model = _FakeModel(reportsBackend
        ? (onGpu ? PreferredBackend.gpu : PreferredBackend.cpu)
        : null);
    models.add(model);
    return model;
  }

  Future<LlmSession> open({
    LlmModelSpec? spec,
    bool supportImage = false,
    int maxNumImages = 1,
  }) =>
      runtime.open(
        spec: spec ?? LlmModelSpec.gemma4E2B,
        temperature: 0,
        topK: 1,
        topP: 1,
        supportImage: supportImage,
        maxNumImages: maxNumImages,
      );

  /// What was asked of the plugin, as (backend, drafter) pairs.
  List<(PreferredBackend, bool)> get asked => [
        for (final r in loads)
          (r.preferredBackend, r.enableSpeculativeDecoding),
      ];
}

LlmModelSpec _specWith({
  bool mtpOnGpu = true,
  ActivationDataType? activationDataType,
}) =>
    LlmModelSpec(
      displayName: 'Test',
      filename: 'test.litertlm',
      downloadUrl: 'https://example.com/test.litertlm',
      approxSizeBytes: 1,
      modelType: ModelType.gemma4,
      fileType: ModelFileType.litertlm,
      maxTokens: 4096,
      speculativeDecodingOnGpu: mtpOnGpu,
      activationDataType: activationDataType,
    );

void main() {
  group('backend and multi-token prediction', () {
    test('on the GPU it asks for the drafter and reports the GPU', () async {
      final h = _Harness();
      await h.open();

      expect(h.asked, [(PreferredBackend.gpu, true)]);
      expect(h.runtime.activeBackend, ComputeBackend.gpu);
    });

    test('a silent fall-back to the CPU is rebuilt without the drafter',
        () async {
      // Asked for the GPU, couldn't get it, and the plugin came up on the CPU
      // with the drafter still enabled — which only adds overhead there.
      final h = _Harness(gpuWorks: false);
      await h.open();

      expect(h.asked, [
        (PreferredBackend.gpu, true),
        (PreferredBackend.cpu, false),
      ]);
      expect(h.models.first.closed, isTrue,
          reason: 'the CPU-with-drafter engine must not stay resident');
      expect(h.runtime.activeBackend, ComputeBackend.cpu);
    });

    test('once the GPU has failed, later loads go straight to the CPU',
        () async {
      final h = _Harness(gpuWorks: false);
      await h.open();
      await h.runtime.releaseModel();
      h.loads.clear();

      await h.open();

      // No second failed GPU attempt, and no drafter.
      expect(h.asked, [(PreferredBackend.cpu, false)]);
    });

    test('the GPU is tried again after a while, not given up on for the session',
        () async {
      final h = _Harness(gpuWorks: false);
      await h.open();
      await h.runtime.releaseModel();
      h.loads.clear();

      h.clock = h.clock.add(EdgeAiRuntime.gpuRetryAfter + const Duration(minutes: 1));
      await h.open();

      expect(h.asked.first, (PreferredBackend.gpu, true));
    });

    test('a spec can switch the drafter off even on a working GPU', () async {
      final h = _Harness();
      await h.open(spec: _specWith(mtpOnGpu: false));

      expect(h.asked, [(PreferredBackend.gpu, false)]);
      expect(h.runtime.activeBackend, ComputeBackend.gpu);
    });

    test('a GPU failure is still remembered when the drafter was never on',
        () async {
      final h = _Harness(gpuWorks: false);
      await h.open(spec: _specWith(mtpOnGpu: false));
      // Nothing to rebuild — the drafter was off — so one load, but the next
      // one must not retry the GPU.
      expect(h.asked, [(PreferredBackend.gpu, false)]);

      await h.runtime.releaseModel();
      h.loads.clear();
      await h.open(spec: _specWith(mtpOnGpu: false));
      expect(h.asked, [(PreferredBackend.cpu, false)]);
    });

    test('a plugin that does not report its backend is left alone', () async {
      final h = _Harness(reportsBackend: false);
      await h.open();

      expect(h.asked, hasLength(1), reason: 'nothing to react to, so no rebuild');
      expect(h.runtime.activeBackend, isNull);
    });
  });

  group('the vision encoder (the plugin now defaults it to the CPU)', () {
    // flutter_gemma 1.3 ran the vision encoder on the model's own backend; 1.11
    // runs it on the CPU unless told otherwise, which would make every image
    // read — the heaviest thing the app does — several times slower. So the
    // runtime states it, and it follows the model.
    test('runs on the GPU alongside a GPU model', () async {
      final h = _Harness();
      await h.open(supportImage: true);

      expect(h.loads.single.preferredVisionBackend, PreferredBackend.gpu);
    });

    test('follows the model to the CPU when the GPU could not be had',
        () async {
      final h = _Harness(gpuWorks: false);
      await h.open(supportImage: true);

      expect(h.loads.map((r) => r.preferredVisionBackend), [
        PreferredBackend.gpu,
        PreferredBackend.cpu,
      ]);
    });

    test('a text-only load names no vision backend', () async {
      final h = _Harness();
      await h.open();

      expect(h.loads.single.preferredVisionBackend, isNull);
    });
  });

  group('a GPU load that throws', () {
    // A delegate that cannot prepare the vision encoder hard-fails the whole
    // load with no fallback of its own. The feature must degrade to the CPU, not
    // die.
    test('is retried on the CPU, with no drafter and no GPU vision encoder',
        () async {
      final h = _Harness(gpuThrows: true);
      await h.open(supportImage: true);

      expect(h.asked, [
        (PreferredBackend.gpu, true),
        (PreferredBackend.cpu, false),
      ]);
      expect(h.loads.last.preferredVisionBackend, PreferredBackend.cpu);
      expect(h.runtime.activeBackend, ComputeBackend.cpu);
    });

    test('is remembered: later loads go straight to the CPU', () async {
      final h = _Harness(gpuThrows: true);
      await h.open();
      await h.runtime.releaseModel();
      h.loads.clear();

      await h.open();

      expect(h.asked, [(PreferredBackend.cpu, false)]);
    });

    test('"no active model" is still not-ready, not a reason to try the CPU',
        () async {
      final h = _Harness(notReady: true);

      await expectLater(h.open(), throwsA(isA<LlmNotReadyException>()));
      expect(h.loads, hasLength(1), reason: 'the CPU would not help');
    });

    test('a CPU load that also throws is reported, not hidden', () async {
      final h = _Harness(gpuThrows: true, cpuThrows: true);

      await expectLater(h.open(), throwsA(isA<Exception>()));
    });
  });

  group('activation data type (wrong digits on some GPUs)', () {
    test('by default the model file decides — nothing is overridden', () async {
      final h = _Harness();
      await h.open();

      expect(h.loads.single.activationDataType, isNull);
    });

    test('a spec that asks for float32 gets it on the GPU', () async {
      final h = _Harness();
      await h.open(spec: _specWith(activationDataType: ActivationDataType.float32));

      expect(h.loads.single.activationDataType, ActivationDataType.float32);
    });

    test('and is not sent for the CPU, where it is already full precision',
        () async {
      final h = _Harness(gpuWorks: false);
      await h.open(spec: _specWith(activationDataType: ActivationDataType.float32));

      expect(h.loads.last.preferredBackend, PreferredBackend.cpu);
      expect(h.loads.last.activationDataType, isNull);
    });

    test('survives a smaller-context profile of the same model', () {
      final lite = _specWith(activationDataType: ActivationDataType.float32)
          .forProfile(AiProfile.lite);

      expect(lite.activationDataType, ActivationDataType.float32);
    });
  });

  group('one resident engine', () {
    test('a repeat call with the same configuration reuses the loaded engine',
        () async {
      final h = _Harness();
      await h.open(supportImage: true);
      await h.open(supportImage: true);

      expect(h.models, hasLength(1));
    });

    test('a call that needs a different configuration rebuilds the engine',
        () async {
      // The plugin would hand back the text-only instance; the runtime has to
      // drop it itself, or whoever called first decides whether images work.
      final h = _Harness();
      await h.open();
      await h.open(supportImage: true);

      expect(h.models, hasLength(2));
      expect(h.models.first.closed, isTrue);
    });

    test('a vision session turns the modality on for the session', () async {
      final h = _Harness();
      await h.open(supportImage: true);

      expect(h.loads.single.supportImage, isTrue);
      expect(h.loads.single.maxNumImages, 1);
      expect(h.models.single.lastSessionArgs?[#enableVisionModality], isTrue);
    });
  });

  group('availability', () {
    test('a model that is not installed is a typed not-ready error', () async {
      final h = _Harness(installed: false);

      await expectLater(h.open(), throwsA(isA<LlmNotReadyException>()));
      expect(h.loads, isEmpty, reason: 'nothing may be loaded');
    });

    test('releasing closes the cached engine, and is safe when none is loaded',
        () async {
      final h = _Harness();
      await h.runtime.releaseModel(); // nothing loaded: must not throw

      await h.open();
      await h.runtime.releaseModel();
      expect(h.models.single.closed, isTrue);
    });
  });
}
