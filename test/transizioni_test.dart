import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cenato/core/tema/tema.dart';
import 'package:cenato/core/tema/transizioni.dart';
import 'package:cenato/data/finto/dipendenze_finte.dart';
import 'package:cenato/domain/modelli/profilo.dart';
import 'package:cenato/main.dart';

/// Animazioni tra le schermate: apertura/chiusura di una pagina e cambio di
/// scheda nella barra in basso. Rispettano "riduci animazioni" del telefono.
void main() {
  group('Transizioni di pagina del tema', () {
    test('su ogni piattaforma c\'è una transizione esplicita', () {
      final builders = temaCenato().pageTransitionsTheme.builders;
      for (final piattaforma in TargetPlatform.values) {
        expect(builders[piattaforma], isNotNull, reason: '$piattaforma');
      }
    });

    test('iOS e macOS mantengono la transizione con gesto indietro', () {
      final builders = temaCenato().pageTransitionsTheme.builders;
      for (final p in [TargetPlatform.iOS, TargetPlatform.macOS]) {
        expect(builders[p], isNot(isA<TransizionePagina>()), reason: '$p');
        expect(
          builders[p].runtimeType.toString(),
          'CupertinoPageTransitionsBuilder',
          reason: '$p',
        );
      }
      expect(builders[TargetPlatform.android], isA<TransizionePagina>());
    });

    testWidgets('con "riduci animazioni" la pagina arriva senza effetti', (
      tester,
    ) async {
      final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      const figlio = SizedBox(key: Key('contenuto'));
      Widget? risultato;
      Future<void> costruisci({required bool ridotto}) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(disableAnimations: ridotto),
            child: Builder(
              builder: (context) {
                risultato =
                    const TransizionePagina(
                      FadeForwardsPageTransitionsBuilder(),
                    ).buildTransitions<void>(
                      route,
                      context,
                      const AlwaysStoppedAnimation(0.5),
                      const AlwaysStoppedAnimation(0),
                      figlio,
                    );
                return const SizedBox();
              },
            ),
          ),
        );
      }

      await costruisci(ridotto: true);
      expect(identical(risultato, figlio), isTrue);
      await costruisci(ridotto: false);
      expect(identical(risultato, figlio), isFalse);
    });
  });

  group('Cambio scheda con dissolvenza', () {
    Future<DipendenzeFinte> avvia(WidgetTester tester) async {
      final finte = DipendenzeFinte(ruolo: Ruolo.nutrizionista);
      await tester.pumpWidget(CenatoApp(dip: finte.dip));
      await tester.pumpAndSettle();
      return finte;
    }

    Finder voceBarra(String etichetta) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(etichetta),
    );

    const sottotitoloPazienti = 'Elenco, filtri e inviti';
    const sottotitoloCalendario = 'Visite e slot liberi';

    testWidgets('a metà animazione le due schede si vedono insieme', (
      tester,
    ) async {
      await avvia(tester);
      await tester.tap(voceBarra('Calendario'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(sottotitoloPazienti), findsOneWidget);
      expect(find.text(sottotitoloCalendario), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text(sottotitoloPazienti), findsNothing);
      expect(find.text(sottotitoloCalendario), findsOneWidget);
    });

    testWidgets('con "riduci animazioni" la nuova scheda compare subito', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await avvia(tester);
      await tester.tap(voceBarra('Calendario'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text(sottotitoloPazienti), findsNothing);
      expect(find.text(sottotitoloCalendario), findsOneWidget);
    });

    testWidgets('tornando alla scheda precedente lo stato è conservato', (
      tester,
    ) async {
      await avvia(tester);
      await tester.enterText(find.byType(TextField), 'sa');
      await tester.pumpAndSettle();
      await tester.tap(voceBarra('Calendario'));
      await tester.pumpAndSettle();
      await tester.tap(voceBarra('Pazienti'));
      await tester.pumpAndSettle();
      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.controller!.text, 'sa');
    });

    // Opacità reale di una scheda in questo istante.
    double opacita(WidgetTester tester, int scheda) => tester
        .renderObject<RenderAnimatedOpacity>(
          find.byKey(ValueKey('dissolvenza-$scheda'), skipOffstage: false),
        )
        .opacity
        .value;

    testWidgets('tornando alla scheda che svanisce non ci sono scatti', (
      tester,
    ) async {
      await avvia(tester);
      await tester.tap(voceBarra('Calendario'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final pazientiPrima = opacita(tester, 0);
      final calendarioPrima = opacita(tester, 1);
      expect(pazientiPrima, inExclusiveRange(0.1, 0.9));

      await tester.tap(voceBarra('Pazienti'));
      await tester.pump();
      expect(opacita(tester, 0), closeTo(pazientiPrima, 0.1));
      expect(opacita(tester, 1), closeTo(calendarioPrima, 0.1));

      await tester.pumpAndSettle();
      expect(find.text(sottotitoloPazienti), findsOneWidget);
      expect(find.text(sottotitoloCalendario), findsNothing);
    });

    testWidgets('tre schede in fila: nessuna scompare di colpo', (
      tester,
    ) async {
      await avvia(tester);
      await tester.tap(voceBarra('Calendario'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final primaA = opacita(tester, 0);
      final primaB = opacita(tester, 1);

      await tester.tap(voceBarra('Profilo'));
      await tester.pump();
      expect(opacita(tester, 0), closeTo(primaA, 0.1));
      expect(opacita(tester, 1), closeTo(primaB, 0.1));

      await tester.pumpAndSettle();
      expect(find.text('Profilo e abbonamento'), findsOneWidget);
      expect(find.text(sottotitoloPazienti), findsNothing);
      expect(find.text(sottotitoloCalendario), findsNothing);
    });

    testWidgets('due cambi rapidi di scheda finiscono sulla scheda scelta', (
      tester,
    ) async {
      await avvia(tester);
      await tester.tap(voceBarra('Calendario'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(voceBarra('Profilo'));
      await tester.pumpAndSettle();
      expect(find.text('Profilo e abbonamento'), findsOneWidget);
      expect(find.text(sottotitoloCalendario), findsNothing);
      expect(find.text(sottotitoloPazienti), findsNothing);
    });
  });
}
