import 'package:flutter/services.dart';

/// Carica in `flutter test` i font veri dell'app (Inter e Plus Jakarta Sans):
/// di default i test usano un font di prova con metriche diverse e non
/// mostrano le parole che vanno a capo a metà.
Future<void> caricaFontReali() async {
  Future<void> carica(String famiglia, List<String> file) async {
    final caricatore = FontLoader(famiglia);
    for (final f in file) {
      caricatore.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await caricatore.load();
  }

  await carica('Inter', [
    'Inter_400Regular.ttf',
    'Inter_500Medium.ttf',
    'Inter_600SemiBold.ttf',
    'Inter_700Bold.ttf',
  ]);
  await carica('PlusJakartaSans', [
    'PlusJakartaSans_600SemiBold.ttf',
    'PlusJakartaSans_700Bold.ttf',
    'PlusJakartaSans_800ExtraBold.ttf',
  ]);
}
