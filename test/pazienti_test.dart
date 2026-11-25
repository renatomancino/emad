import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cenato/data/finto/dipendenze_finte.dart';
import 'package:cenato/data/finto/pazienti_repository_finto.dart';
import 'package:cenato/domain/modelli/paziente.dart';
import 'package:cenato/domain/modelli/piano.dart';
import 'package:cenato/domain/modelli/profilo.dart';
import 'package:cenato/main.dart';
import 'package:cenato/presentation/comuni/componenti.dart';
import 'package:cenato/presentation/comuni/segnaposto_page.dart';
import 'package:cenato/presentation/nutrizionista/sponsor_card.dart';

import 'font_reali.dart';

/// Schede della fase 1: Piani e abbonamento, Inviti, Elenco pazienti.
/// Flussi delle schermate con dati finti (nessun database).
void main() {
  Future<DatiFinti> avviaNut(WidgetTester tester, DatiFinti dati) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CenatoApp(
        dip: DipendenzeFinte(ruolo: Ruolo.nutrizionista, dati: dati).dip,
      ),
    );
    await tester.pumpAndSettle();
    return dati;
  }

  testWidgets('filtri Attivi / Archiviati / Tutti e ricerca per nome', (
    tester,
  ) async {
    await avviaNut(tester, DatiFinti());
    expect(find.text('Marco'), findsOneWidget);
    expect(find.text('Luca'), findsNothing); // archiviato, filtro Attivi

    await tester.tap(find.text('Archiviati'));
    await tester.pumpAndSettle();
    expect(find.text('Luca'), findsOneWidget);
    expect(find.text('Marco'), findsNothing);

    await tester.tap(find.text('Tutti'));
    await tester.pumpAndSettle();
    expect(find.text('Marco'), findsOneWidget);
    expect(find.text('Luca'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sa');
    await tester.pumpAndSettle();
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('Marco'), findsNothing);
  });

  testWidgets(
    'Free con 1 paziente: Invita mostra l\'errore, niente archiviazione',
    (tester) async {
      final dati = DatiFinti(
        piano: PianoAbbonamento.free,
        pazienti: [
          const PazienteElenco(
            id: 'a',
            nome: 'Anna',
            stato: StatoPaziente.attivo,
          ),
        ],
      )..periodo = null;
      await avviaNut(tester, dati);
      expect(find.text('Spazio sponsor'), findsOneWidget); // solo nel Free

      await tester.tap(find.text('Invita'));
      await tester.pumpAndSettle();
      expect(find.text('Limite del piano raggiunto'), findsOneWidget);
      expect(
        find.text('Hai raggiunto il limite del piano Free (1 paziente).'),
        findsOneWidget,
      );
      expect(find.text('Archivia un paziente'), findsNothing);

      // "Cambia piano" porta all'abbonamento; il pagamento è simulato.
      await tester.tap(find.text('Cambia piano'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('piano-attuale')), findsOneWidget);
      await tester.tap(find.text('Passa a Start'));
      await tester.pumpAndSettle();
      expect(find.text('Pagamento simulato: nessun addebito.'), findsOneWidget);
      await tester.tap(find.text('Conferma'));
      await tester.pumpAndSettle();
      expect(dati.piano, PianoAbbonamento.start);
      // Lo SnackBar di conferma copre il pulsante Invita: si attende che sparisca.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Dopo il passaggio a Start l'invito funziona e lo sponsor sparisce.
      await tester.tap(find.text('Pazienti'));
      await tester.pumpAndSettle();
      expect(find.text('Spazio sponsor'), findsNothing);
      await tester.tap(find.text('Invita'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crea invito'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('codice-invito')), findsOneWidget);
      expect(dati.inviti.single.stato, StatoInvito.creato);
    },
  );

  testWidgets('lo sponsor non compare nei piani Start e Pro', (tester) async {
    await avviaNut(tester, DatiFinti(piano: PianoAbbonamento.pro));
    expect(find.text('Spazio sponsor'), findsNothing);
  });

  testWidgets('invito in attesa revocato (RF_GI_8)', (tester) async {
    final dati = DatiFinti();
    await avviaNut(tester, dati);
    await tester.tap(find.text('Invita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crea invito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Torna ai pazienti'));
    await tester.pumpAndSettle();

    expect(find.text('Inviti in attesa'), findsOneWidget);
    await tester.tap(find.text('Revoca'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Revoca'));
    await tester.pumpAndSettle();
    expect(dati.inviti.single.stato, StatoInvito.revocato);
    expect(find.text('Inviti in attesa'), findsNothing);
  });

  testWidgets('archiviazione con conferma e riattivazione', (tester) async {
    final dati = DatiFinti(piano: PianoAbbonamento.start);
    await avviaNut(tester, dati);

    await tester.tap(find.text('Marco'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archivia'));
    await tester.pumpAndSettle();
    expect(find.textContaining('non viene eliminato'), findsOneWidget);
    expect(find.textContaining('libera un posto'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Archivia'));
    await tester.pumpAndSettle();
    expect(
      dati.pazienti.firstWhere((p) => p.nome == 'Marco').stato,
      StatoPaziente.archiviato,
    );

    await tester.tap(find.text('Archiviati'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marco'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Riattiva'));
    await tester.pumpAndSettle();
    expect(
      dati.pazienti.firstWhere((p) => p.nome == 'Marco').stato,
      StatoPaziente.attivo,
    );
  });

  testWidgets(
    'Start al limite: la riattivazione propone cambio piano o archiviazione',
    (tester) async {
      final dati = DatiFinti(
        piano: PianoAbbonamento.start,
        pazienti: [
          for (var i = 1; i <= 5; i++)
            PazienteElenco(
              id: 'a$i',
              nome: 'Attivo $i',
              stato: StatoPaziente.attivo,
            ),
          const PazienteElenco(
            id: 'z',
            nome: 'Zeno',
            stato: StatoPaziente.archiviato,
          ),
        ],
      );
      await avviaNut(tester, dati);
      await tester.tap(find.text('Archiviati'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zeno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riattiva'));
      await tester.pumpAndSettle();
      expect(find.text('Limite del piano raggiunto'), findsOneWidget);
      expect(find.text('Archivia un paziente'), findsOneWidget);
      expect(dati.pazienti.last.stato, StatoPaziente.archiviato);
    },
  );

  group('Aspetto su telefono stretto e testo grande', () {
    // Font veri caricati una volta sola, prima dei test del gruppo.
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await caricaFontReali();
    });

    // 320 dp di larghezza e testo di sistema al 200% (RNF_U_3).
    Future<void> avviaStretto(
      WidgetTester tester,
      DatiFinti dati, {
      double scala = 2,
    }) async {
      tester.view.physicalSize = const Size(640, 2400);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = scala;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        CenatoApp(
          dip: DipendenzeFinte(ruolo: Ruolo.nutrizionista, dati: dati).dip,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tocca(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    testWidgets('elenco: righe in card e nome lunghissimo', (tester) async {
      await avviaStretto(
        tester,
        DatiFinti(
          pazienti: [
            PazienteElenco(
              id: 'a',
              nome: ('Maria ' * 12).trim(),
              stato: StatoPaziente.attivo,
            ),
            const PazienteElenco(
              id: 'b',
              nome: 'Marco',
              stato: StatoPaziente.attivo,
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(RigaElenco), findsNWidgets(2));
      expect(find.text('Marco'), findsOneWidget);
    });

    testWidgets('piano Free: scheda sponsor senza overflow', (tester) async {
      await avviaStretto(tester, DatiFinti(piano: PianoAbbonamento.free));
      expect(tester.takeException(), isNull);
      expect(find.byType(SponsorCard), findsOneWidget);
    });

    testWidgets('abbonamento: piano attuale come etichetta, senza overflow', (
      tester,
    ) async {
      await avviaStretto(tester, DatiFinti(piano: PianoAbbonamento.free));
      await tocca(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profilo'),
        ),
      );
      expect(tester.takeException(), isNull);
      // A testo grande le schede stanno sotto: si scorre fin lì.
      await tester.scrollUntilVisible(
        find.text('Annuale (2 mesi gratis)'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.widgetWithText(EtichettaStato, 'Attuale'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(EtichettaStato, 'Attuale'), findsOneWidget);
    });

    // Con i font veri: il font di prova dei test non mostra le parole spezzate.
    double altezzaTesto(WidgetTester tester, String testo) =>
        tester.getSize(find.text(testo)).height;

    testWidgets('filtri: ogni etichetta su una riga a 320 dp, testo normale', (
      tester,
    ) async {
      await avviaStretto(tester, DatiFinti(), scala: 1);
      expect(tester.takeException(), isNull);
      expect(
        altezzaTesto(tester, 'Archiviati'),
        closeTo(altezzaTesto(tester, 'Tutti'), 0.5),
      );
      expect(
        altezzaTesto(tester, 'Attivi'),
        closeTo(altezzaTesto(tester, 'Tutti'), 0.5),
      );
    });

    testWidgets('filtri: nessuna parola spezzata con testo al 200%', (
      tester,
    ) async {
      await avviaStretto(tester, DatiFinti());
      expect(tester.takeException(), isNull);
      expect(
        altezzaTesto(tester, 'Archiviati'),
        closeTo(altezzaTesto(tester, 'Tutti'), 0.5),
      );
    });

    testWidgets('filtro: tocco su Archiviati cambia l\'elenco', (tester) async {
      await avviaStretto(tester, DatiFinti(), scala: 1);
      await tocca(tester, find.text('Archiviati'));
      expect(find.text('Luca'), findsOneWidget);
      expect(find.text('Marco'), findsNothing);
    });

    testWidgets('abbonamento: periodo su una riga a 320 dp, testo normale', (
      tester,
    ) async {
      await avviaStretto(
        tester,
        DatiFinti(piano: PianoAbbonamento.free),
        scala: 1,
      );
      await tocca(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profilo'),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Annuale (2 mesi gratis)'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(
        altezzaTesto(tester, 'Annuale (2 mesi gratis)'),
        closeTo(altezzaTesto(tester, 'Mensile'), 0.5),
      );
    });

    testWidgets('invito: creazione e codice senza overflow', (tester) async {
      await avviaStretto(tester, DatiFinti());
      await tocca(tester, find.text('Invita'));
      expect(tester.takeException(), isNull);
      await tocca(tester, find.text('Crea invito'));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('codice-invito')), findsOneWidget);
    });
  });
}
