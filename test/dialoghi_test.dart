import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cenato/core/tema/tema.dart';
import 'package:cenato/domain/modelli/piano.dart';
import 'package:cenato/domain/repository/pazienti_repository.dart';
import 'package:cenato/presentation/comuni/errore_limite_dialog.dart';

import 'font_reali.dart';

/// Dialogo "Limite del piano raggiunto" (RF_GAD_7) su telefoni piccoli.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await caricaFontReali();
  });

  Future<void> apriDialogo(
    WidgetTester tester, {
    required Size dp,
    required double scala,
  }) async {
    tester.view.physicalSize = Size(dp.width * 2, dp.height * 2);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = scala;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: temaCenato(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => mostraErroreLimite(
                context,
                const ErroreLimitePiano(
                  'Hai raggiunto il limite del piano Start (5 pazienti attivi).',
                  piano: PianoAbbonamento.start,
                ),
                onCambiaPiano: () {},
                onArchivia: () {},
              ),
              child: const Text('Apri'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();
  }

  testWidgets('a testo normale mostra motivo e tre azioni', (tester) async {
    await apriDialogo(tester, dp: const Size(360, 780), scala: 1);
    expect(tester.takeException(), isNull);
    expect(find.text('Limite del piano raggiunto'), findsOneWidget);
    expect(find.text('Cambia piano'), findsOneWidget);
    expect(find.text('Archivia un paziente'), findsOneWidget);
    expect(find.text('Chiudi'), findsOneWidget);
  });

  testWidgets('320x640 dp con testo al 200%: nessun overflow', (tester) async {
    await apriDialogo(tester, dp: const Size(320, 640), scala: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Limite del piano raggiunto'), findsOneWidget);
  });

  testWidgets('360x640 dp con testo al 200%: nessun overflow', (tester) async {
    await apriDialogo(tester, dp: const Size(360, 640), scala: 2);
    expect(tester.takeException(), isNull);
  });
}
