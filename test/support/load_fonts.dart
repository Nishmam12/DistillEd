// Loads the app's real typeface into the test engine.
//
// flutter_test renders every glyph with the Ahem font (one em wide) unless a
// family is loaded, which makes text look roughly twice as wide as it is and
// turns responsive tests into noise. Load Modulus Pro so layout is measured
// with the widths users will actually see.

import 'package:flutter/services.dart';

Future<void> loadAppFonts() async {
  final loader = FontLoader('ModulusPro')
    ..addFont(rootBundle.load('assets/fonts/ModulusPro-Regular.otf'))
    ..addFont(rootBundle.load('assets/fonts/ModulusPro-Medium.otf'))
    ..addFont(rootBundle.load('assets/fonts/ModulusPro-SemiBold.otf'));
  await loader.load();
}
