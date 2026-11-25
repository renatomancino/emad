import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cenato/core/tema/tema.dart';
import 'package:cenato/presentation/comuni/componenti.dart';
import 'package:cenato/presentation/comuni/segnaposto_page.dart';
import 'package:cenato/presentation/comuni/stati_view.dart';

/// App di prova con il tema reale; [scala] imita la dimensione del testo
/// scelta nelle impostazioni del telefono.
Widget _inApp(
  Widget figlio, {
  double scala = 1,
  PreferredSizeWidget? intestazione,
}) => MaterialApp(
  theme: temaCenato(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scala)),
    child: child!,
  ),
  home: Scaffold(appBar: intestazione, body: figlio),
);

/// Rapporto di contrasto WCAG.
double _contrasto(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final chiaro = la > lb ? la : lb;
  final scuro = la > lb ? lb : la;
  return (chiaro + 0.05) / (scuro + 0.05);
}

/// Contenitore largo come un telefono stretto (320 dp).
Widget _stretto(Widget figlio) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(width: 320, child: figlio),
);

void main() {
  group('IntestazioneSezione', () {
    testWidgets('mostra titolo e sottotitolo su sfondo chiaro, senza fascia', (
      tester,
    ) async {
      await tester.pumpWidget(
        _inApp(
          const SizedBox(),
          intestazione: const IntestazioneSezione(
            titolo: 'Oggi',
            sottotitolo: 'Pasti di oggi e check-in',
          ),
        ),
      );
      expect(find.text('Oggi'), findsOneWidget);
      expect(find.text('Pasti di oggi e check-in'), findsOneWidget);
      final barra = tester.widget<AppBar>(find.byType(AppBar));
      expect(barra.backgroundColor, CenatoColori.chiaro.sfondo);
    });

    testWidgets('mostra le azioni a destra', (tester) async {
      var toccato = false;
      await tester.pumpWidget(
        _inApp(
          const SizedBox(),
          intestazione: IntestazioneSezione(
            titolo: 'Oggi',
            azioni: [
              IconButton(
                tooltip: 'Profilo',
                icon: const Icon(Icons.account_circle_outlined),
                onPressed: () => toccato = true,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byTooltip('Profilo'));
      expect(toccato, isTrue);
    });
  });

  group('RigaElenco', () {
    testWidgets('ha altezza minima 64 e richiama onTap', (tester) async {
      var toccato = false;
      await tester.pumpWidget(
        _inApp(RigaElenco(titolo: 'Marco', onTap: () => toccato = true)),
      );
      expect(
        tester.getSize(find.byType(RigaElenco)).height,
        greaterThanOrEqualTo(64),
      );
      await tester.tap(find.text('Marco'));
      expect(toccato, isTrue);
    });

    testWidgets('tronca un nome di 80 caratteri senza overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _inApp(
          _stretto(
            RigaElenco(
              titolo: 'Maria ' * 14,
              sottotitolo: 'Sottotitolo molto lungo ' * 6,
              leading: const IconaTonale(icona: Icons.person),
              trailing: const EtichettaStato(testo: 'Archiviato'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a testo 200% su 320 dp non va in overflow', (tester) async {
      await tester.pumpWidget(
        _inApp(
          _stretto(
            const RigaElenco(
              titolo: 'Marco Rossi',
              sottotitolo: 'Semaforo e ultimo check-in',
              leading: IconaTonale(icona: Icons.person),
              trailing: EtichettaStato(testo: 'Collegamento interrotto'),
            ),
          ),
          scala: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Marco Rossi'), findsOneWidget);
    });
  });

  group('Dimensione del testo nell\'intestazione', () {
    Future<double> altezzaTitolo(
      WidgetTester tester, {
      required double scala,
      String? sottotitolo,
    }) async {
      tester.view.physicalSize = const Size(640, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _inApp(
          const SizedBox(),
          scala: scala,
          intestazione: IntestazioneSezione(
            titolo: 'Pazienti',
            sottotitolo: sottotitolo,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final titolo = find.text('Pazienti');
      // Altezza disegnata (tiene conto di eventuali trasformazioni).
      return tester.getBottomRight(titolo).dy - tester.getTopLeft(titolo).dy;
    }

    testWidgets('un sottotitolo lungo non rimpicciolisce il titolo', (
      tester,
    ) async {
      final solo = await altezzaTitolo(tester, scala: 1);
      final conLungo = await altezzaTitolo(
        tester,
        scala: 1,
        sottotitolo: 'Sottotitolo molto lungo, ' * 3,
      );
      expect(conLungo, closeTo(solo, 0.5));
    });

    testWidgets('con testo al 200% il titolo non è più piccolo che al 100%', (
      tester,
    ) async {
      final normale = await altezzaTitolo(tester, scala: 1);
      final grande = await altezzaTitolo(
        tester,
        scala: 2,
        sottotitolo: 'Elenco, filtri e inviti',
      );
      expect(grande, greaterThanOrEqualTo(normale));
    });

    testWidgets('solo il titolo è un\'intestazione per lo screen reader', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(
        _inApp(
          const SizedBox(),
          intestazione: const IntestazioneSezione(
            titolo: 'Pazienti',
            sottotitolo: 'Elenco, filtri e inviti',
          ),
        ),
      );
      expect(tester.getSemantics(find.text('Pazienti')).label, 'Pazienti');
      semantica.dispose();
    });
  });

  group('RigaElenco: spazio al titolo', () {
    testWidgets(
      'il titolo usa tutto lo spazio che l\'etichetta lascia libero',
      (tester) async {
        await tester.pumpWidget(
          _inApp(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 390,
                child: RigaElenco(
                  titolo: 'W' * 60,
                  leading: const IconaTonale(icona: Icons.person),
                  trailing: const EtichettaStato(testo: 'Attivo'),
                ),
              ),
            ),
          ),
        );
        // Riga 390 − padding 32 − icona 44 − 2 spazi da 12 − etichetta.
        final libero =
            390 -
            32 -
            44 -
            24 -
            tester.getSize(find.byType(EtichettaStato)).width;
        expect(
          tester.getSize(find.text('W' * 60)).width,
          greaterThanOrEqualTo(libero - 24),
        );
      },
    );
  });

  group('Testo al 200% su 320 dp', () {
    testWidgets('intestazione con titolo e sottotitolo lunghi', (tester) async {
      tester.view.physicalSize = const Size(640, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _inApp(
          const SizedBox(),
          scala: 2,
          intestazione: const IntestazioneSezione(
            titolo: 'Profilo e abbonamento',
            sottotitolo: 'Piano, fatturazione e account',
            azioni: [Icon(Icons.account_circle_outlined)],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('StatoVuotoView ed ErroreView', (tester) async {
      tester.view.physicalSize = const Size(640, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _inApp(
          StatoVuotoView(
            icona: Icons.groups,
            titolo: 'Nessun paziente',
            messaggio: 'Invita il tuo primo paziente: riceverà un codice.',
            etichettaAzione: 'Invita un paziente',
            onAzione: () {},
          ),
          scala: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Invita un paziente'), findsOneWidget);
      await tester.pumpWidget(
        _inApp(
          ErroreView(messaggio: 'Rete assente', onRiprova: () {}),
          scala: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('EtichettaStato', () {
    testWidgets('mostra sempre il testo e cambia colore con il tono', (
      tester,
    ) async {
      Color? sfondoDi(TonoStato tono) {
        final deco =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byType(EtichettaStato),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as ShapeDecoration;
        return deco.color;
      }

      final sfondi = <TonoStato, Color?>{};
      for (final tono in TonoStato.values) {
        await tester.pumpWidget(
          _inApp(
            Center(
              child: EtichettaStato(testo: 'Stato', tono: tono),
            ),
          ),
        );
        expect(find.text('Stato'), findsOneWidget);
        sfondi[tono] = sfondoDi(tono);
      }
      expect(sfondi.values.toSet().length, TonoStato.values.length);
    });

    testWidgets('ogni tono ha contrasto AA tra testo e sfondo', (tester) async {
      for (final tono in TonoStato.values) {
        await tester.pumpWidget(
          _inApp(
            Center(
              child: EtichettaStato(testo: 'Stato', tono: tono),
            ),
          ),
        );
        final deco =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byType(EtichettaStato),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as ShapeDecoration;
        final colorTesto = tester
            .widget<Text>(find.text('Stato'))
            .style!
            .color!;
        expect(
          _contrasto(colorTesto, deco.color!),
          greaterThanOrEqualTo(4.5),
          reason: '$tono',
        );
      }
    });

    testWidgets('il tono predefinito è positivo', (tester) async {
      await tester.pumpWidget(
        _inApp(const Center(child: EtichettaStato(testo: 'Attivo'))),
      );
      final deco =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(EtichettaStato),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as ShapeDecoration;
      expect(deco.color, CenatoColori.chiaro.primarioTonale);
    });
  });

  group('IconaTonale e SchedaSezione', () {
    testWidgets('IconaTonale rispetta la dimensione richiesta', (tester) async {
      await tester.pumpWidget(
        _inApp(
          const Column(
            children: [
              IconaTonale(icona: Icons.person),
              IconaTonale(icona: Icons.person, dimensione: 72),
            ],
          ),
        ),
      );
      final dimensioni = tester
          .widgetList(find.byType(IconaTonale))
          .map((w) => tester.getSize(find.byWidget(w)))
          .toList();
      expect(dimensioni, const [Size(44, 44), Size(72, 72)]);
    });

    testWidgets('SchedaSezione mostra titolo e contenuto e gestisce onTap', (
      tester,
    ) async {
      var toccato = false;
      await tester.pumpWidget(
        _inApp(
          SchedaSezione(
            titolo: 'Obiettivi',
            onTap: () => toccato = true,
            child: const Text('2.000 kcal'),
          ),
        ),
      );
      expect(find.text('Obiettivi'), findsOneWidget);
      expect(find.text('2.000 kcal'), findsOneWidget);
      await tester.tap(find.text('2.000 kcal'));
      expect(toccato, isTrue);
    });

    testWidgets('SchedaSezione senza titolo mostra solo il contenuto', (
      tester,
    ) async {
      await tester.pumpWidget(
        _inApp(const SchedaSezione(child: Text('Solo contenuto'))),
      );
      expect(find.text('Solo contenuto'), findsOneWidget);
    });
  });
}
