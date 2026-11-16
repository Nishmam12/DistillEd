// A cloud AI the student added with their own key: where it is, what they
// called it, and which of its models they want in the list.
//
// The key itself is NOT here. This is the part that is safe to keep in plain
// preferences; the key lives in the platform keystore (see
// `data/catalog/user_connection_store.dart`).

import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;

import 'ai_model_entry.dart';

/// The window given to a model whose real one is not known. Small on purpose:
/// every prompt is budgeted from this number, and a guess that is too large
/// sends more than the model can read.
const int kUnknownModelWindowTokens = 8000;

@immutable
class UserModel {
  /// The provider's own name for the model, sent on the wire.
  final String modelId;
  final String displayName;
  final int contextWindowTokens;
  final bool supportsTools;

  const UserModel({
    required this.modelId,
    required this.displayName,
    this.contextWindowTokens = kUnknownModelWindowTokens,
    this.supportsTools = false,
  });

  Map<String, dynamic> toJson() => {
        'modelId': modelId,
        'displayName': displayName,
        'contextWindowTokens': contextWindowTokens,
        'supportsTools': supportsTools,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        modelId: json['modelId'] as String,
        displayName: json['displayName'] as String,
        contextWindowTokens:
            json['contextWindowTokens'] as int? ?? kUnknownModelWindowTokens,
        supportsTools: json['supportsTools'] as bool? ?? false,
      );
}

@immutable
class UserConnection {
  final String id;

  /// What the student called it.
  final String label;
  final String presetId;
  final String baseUrl;
  final List<UserModel> models;

  /// Whether the student has already been told, once, where text sent to this
  /// connection goes.
  final bool consentShown;

  const UserConnection({
    required this.id,
    required this.label,
    required this.presetId,
    required this.baseUrl,
    this.models = const [],
    this.consentShown = false,
  });

  /// The host text is sent to, for the consent wording.
  String get host => Uri.tryParse(baseUrl)?.host ?? baseUrl;

  /// This connection's rows in the model list.
  List<AiModelEntry> get entries => [
        for (final model in models)
          AiModelEntry(
            id: AiModelEntry.userModelId(id, model.modelId),
            displayName: '$label · ${model.displayName}',
            source: ModelSource.userKey,
            contextWindowTokens: model.contextWindowTokens,
            supportsTools: model.supportsTools,
            host: host,
          ),
      ];

  UserConnection copyWith({
    String? id,
    String? label,
    String? presetId,
    String? baseUrl,
    List<UserModel>? models,
    bool? consentShown,
  }) =>
      UserConnection(
        id: id ?? this.id,
        label: label ?? this.label,
        presetId: presetId ?? this.presetId,
        baseUrl: baseUrl ?? this.baseUrl,
        models: models ?? this.models,
        consentShown: consentShown ?? this.consentShown,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'presetId': presetId,
        'baseUrl': baseUrl,
        'models': [for (final m in models) m.toJson()],
        'consentShown': consentShown,
      };

  factory UserConnection.fromJson(Map<String, dynamic> json) => UserConnection(
        id: json['id'] as String,
        label: json['label'] as String,
        presetId: json['presetId'] as String? ?? 'custom',
        baseUrl: json['baseUrl'] as String,
        models: [
          for (final m in json['models'] as List<dynamic>? ?? const [])
            UserModel.fromJson(m as Map<String, dynamic>),
        ],
        consentShown: json['consentShown'] as bool? ?? false,
      );
}

String encodeConnections(List<UserConnection> connections) =>
    jsonEncode([for (final c in connections) c.toJson()]);

/// Reads what [encodeConnections] wrote. Anything unreadable is dropped rather
/// than thrown: a damaged preference must cost one connection, not the app.
List<UserConnection> decodeConnections(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  final connections = <UserConnection>[];
  for (final item in decoded) {
    try {
      connections.add(UserConnection.fromJson(item as Map<String, dynamic>));
    } on TypeError {
      // One entry this build cannot read; keep the rest.
    }
  }
  return connections;
}

/// Why [url] cannot be used as a connection's address, or null when it can.
///
/// Https only: the key travels in a header on every request, and over plain
/// http anyone on the same network reads it.
String? validateBaseUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'Enter the full address, starting with https://';
  }
  if (uri.scheme != 'https') {
    return 'The address must start with https:// so your key is sent securely.';
  }
  return null;
}
