// Where the on-device model actually runs.
//
// Known only AFTER a model has loaded, never before: the runtime asks for the
// GPU and, when it can't have it, falls back to the CPU without telling the
// caller. A 2B model on a phone CPU is several times slower, so everything that
// would otherwise assume "fast" — routing, optional passes, output budgets —
// needs to be able to ask what it really got.

/// The accelerator behind the loaded on-device model.
enum ComputeBackend {
  gpu,
  npu,
  cpu;

  /// True when the model is several times slower than on an accelerator, which
  /// is the cue to skip optional work and prefer the cloud for users who have
  /// opted in.
  bool get isSlow => this == ComputeBackend.cpu;
}
