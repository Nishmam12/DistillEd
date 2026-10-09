// What the user said about downloading a new search model on mobile data.

import 'package:shared_preferences/shared_preferences.dart';

enum MobileDataChoice { ask, wifiOnly, allow }

const _key = 'embedder.mobileDataChoice';

Future<MobileDataChoice> loadMobileDataChoice() async {
  final name = (await SharedPreferences.getInstance()).getString(_key);
  return MobileDataChoice.values
      .firstWhere((c) => c.name == name, orElse: () => MobileDataChoice.ask);
}

Future<void> saveMobileDataChoice(MobileDataChoice choice) async =>
    (await SharedPreferences.getInstance()).setString(_key, choice.name);
