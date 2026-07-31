// Where a piece of AI output actually came from, so the UI can say so.
//
// This exists because "is my note being sent to the cloud?" was unanswerable
// from the app: the sidebar's cloud switch showed a SETTING, not what ran, and
// with the switch on a page could still be read entirely on-device (the setting
// only ever meant "you may escalate"). Nothing in the log answered it either.
//
// The distinction the UI has to draw is not local-vs-cloud in general, but
// whether THIS output involved sending note content off the device.

/// Which tier produced a given piece of AI output.
enum AiRanOn {
  /// The on-device model. No note content left the device.
  onDevice,

  /// The cloud gateway, because the user chose cloud-first. Note content was
  /// sent off the device.
  cloudPreferred,

  /// The cloud gateway, reached for only after the on-device read failed its
  /// quality check. Note content was sent off the device.
  cloudEscalated;

  /// True when producing this output sent note content off the device — the
  /// one question the indicator has to answer honestly.
  bool get leftDevice => this != AiRanOn.onDevice;

  /// Short label for the badge.
  String get label => switch (this) {
        AiRanOn.onDevice => 'On-device',
        AiRanOn.cloudPreferred => 'Cloud',
        AiRanOn.cloudEscalated => 'Cloud',
      };

  /// The sentence the tooltip shows. Says what happened and why, because
  /// "Cloud" alone does not tell someone whether they chose that.
  String get explanation => switch (this) {
        AiRanOn.onDevice =>
          'Read on this device. Nothing was sent anywhere.',
        AiRanOn.cloudPreferred =>
          'Read in the cloud, because AI processing is set to Cloud. '
              'This page was sent to the gateway.',
        AiRanOn.cloudEscalated =>
          'The on-device model could not read this page, so it was re-read '
              'in the cloud. This page was sent to the gateway.',
      };
}

/// Where the RETRIEVAL half of RAG runs.
///
/// Deliberately not a variable: embeddings are model-locked and never routed
/// (`domain/rag/text_embedder.dart`), the embedder provider is hardcoded to
/// [LocalTextEmbedder], and `CloudGatewayProvider.embed` throws
/// [AiUnsupportedOperationException] because no embedding endpoint exists.
///
/// So note chunks are embedded on-device and the vectors are stored in Isar on
/// the device. Search is brute-force cosine similarity in Dart over those local
/// vectors. This is a constant so the UI can state it as fact rather than
/// implying it might sometimes be otherwise — and so that if a cloud embedder
/// is ever added, every place that made this promise fails to compile.
const bool kRagRetrievalIsAlwaysOnDevice = true;
