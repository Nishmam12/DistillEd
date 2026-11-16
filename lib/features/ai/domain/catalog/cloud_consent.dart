// When the student must be asked before their text is sent to a cloud model
// they picked.

import '../../../../core/providers/settings_provider.dart' show CloudPrivacy;

/// True when a send has to wait for a yes.
///
/// - Under `askEachTime`, always: that is what the setting promises.
/// - On the very first cloud call from this app, whatever the setting, so
///   nobody's first cloud request is a surprise.
/// - The first time a newly added model is used, because it is a different
///   company receiving the text.
///
/// Asked once per thing the student does, not once per request: summarizing a
/// long notebook makes several requests and is still one question.
bool needsSendConfirmation({
  required CloudPrivacy privacy,
  required bool firstEverCloudCall,
  required bool firstUseOfModel,
}) =>
    privacy == CloudPrivacy.askEachTime ||
    firstEverCloudCall ||
    firstUseOfModel;
