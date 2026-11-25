import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cenato/data/finto/dipendenze_finte.dart';
import 'package:cenato/data/finto/obiettivi_repository_finto.dart';
import 'package:cenato/data/supabase/obiettivi_repository_supabase.dart';
import 'package:cenato/domain/modelli/obiettivi.dart';
import 'package:cenato/domain/modelli/profilo.dart';
import 'package:cenato/domain/regole/obiettivi.dart';
import 'package:cenato/domain/repository/pazienti_repository.dart';
import 'package:cenato/main.dart';

/// Scheda "Obiettivi nutrizionali" (UC_GP_6, RF_GP_16, SC_GP_4).
void main() {
  group('kcalDaMacro (4/4/9 kcal per grammo)', () {
    test('valori di SC_GP_4: 110 g P, 230 g C, 65 g G', () {
      // 110*4 + 230*4 + 65*9 = 440 + 920 + 585
      expect(kcalDaMacro(110, 230, 65), 1945);
    });
    test('zero e decimali', () {
      expect(kcalDaMacro(0, 0, 0), 0);
      expect(kcalDaMacro(10.5, 0, 1), closeTo(51, 1e-9));
    });
  });

  group('Validazione', () {
    test('kcal: intero tra 800 e 6000', () {
      expect(ValidazioneObiettivi.kcal('2000'), isNull);
      expect(ValidazioneObiettivi.kcal('800'), isNull);
      expect(ValidazioneObiettivi.kcal('6000'), isNull);
      expect(ValidazioneObiettivi.kcal('799'), isNotNull);
      expect(ValidazioneObiettivi.kcal('6001'), isNotNull);
      expect(ValidazioneObiettivi.kcal(''), isNotNull);
      expect(ValidazioneObiettivi.kcal('abc'), isNotNull);
      expect(ValidazioneObiettivi.kcal('-2000'), isNotNull);
      expect(ValidazioneObiettivi.kcal('2000,5'), isNotNull);
    });
    test('macro: maggiori di zero, massimo 1000 g, un decimale', () {
      expect(ValidazioneObiettivi.macro('110', 'Proteine'), isNull);
      expect(ValidazioneObiettivi.macro('110,5', 'Proteine'), isNull);
      expect(ValidazioneObiettivi.macro('110.5', 'Proteine'), isNull);
      expect(ValidazioneObiettivi.macro('0', 'Proteine'), isNotNull);
      expect(ValidazioneObiettivi.macro('-5', 'Grassi'), isNotNull);
      expect(ValidazioneObiettivi.macro('1000', 'Grassi'), isNull);
      expect(ValidazioneObiettivi.macro('1001', 'Grassi'), isNotNull);
      expect(ValidazioneObiettivi.macro('12,34', 'Grassi'), isNotNull);
      expect(ValidazioneObiettivi.macro('', 'Grassi'), isNotNull);
    });
    test('avviso di coerenza: solo oltre la tolleranza del 10 %', () {
      // SC_GP_4: 1945 kcal dai macro contro 2000 indicate (2,75 %)
      expect(
        ValidazioneObiettivi.avvisoCoerenza(
          kcal: 2000,
          proteineG: 110,
          carboidratiG: 230,
          grassiG: 65,
        ),
        isNull,
      );
      // 1945 kcal dai macro contro 2500 indicate (22 %)
      expect(
        ValidazioneObiettivi.avvisoCoerenza(
          kcal: 2500,
          proteineG: 110,
          carboidratiG: 230,
          grassiG: 65,
        ),
        allOf(contains('1945'), contains('2500')),
      );
    });
  });

  group('Repository finto: storico e obiettivo corrente', () {
    test('senza obiettivi la corrente è nulla', () async {
      final r = ObiettiviRepositoryFinto();
      expect(await r.corrente('p1'), isNull);
      expect(await r.storico('p1'), isEmpty);
    });

    test('ogni modifica è una nuova riga: la corrente è l\'ultima', () async {
      final r = ObiettiviRepositoryFinto();
      await r.imposta(
        'p1',
        kcal: 2000,
        proteineG: 110,
        carboidratiG: 230,
        grassiG: 65,
      );
      await r.imposta(
        'p1',
        kcal: 1900,
        proteineG: 105,
        carboidratiG: 210,
        grassiG: 60,
      );
      expect((await r.corrente('p1'))!.kcal, 1900);
      expect((await r.storico('p1')).map((o) => o.kcal), [1900, 2000]);
      expect(await r.corrente('p2'), isNull);
    });

    test('osserva riemette il valore dopo ogni salvataggio', () async {
      final r = ObiettiviRepositoryFinto();
      final visti = <int?>[];
      final sub = r.osserva('p1').listen((o) => visti.add(o?.kcal));
      await Future<void>.delayed(Duration.zero);
      await r.imposta(
        'p1',
        kcal: 2000,
        proteineG: 110,
        carboidratiG: 230,
        grassiG: 65,
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(visti, [null, 2000]);
    });
  });

  group('Supabase (finto PostgREST)', () {
    late List<http.Request> richieste;

    ObiettiviRepositorySupabase repo(http.Response Function(http.Request) f) {
      richieste = [];
      final db = SupabaseClient(
        'https://prova.supabase.co',
        'chiave-anon',
        httpClient: MockClient((r) async {
          richieste.add(r);
          final ris = f(r);
          return http.Response.bytes(
            ris.bodyBytes,
            ris.statusCode,
            headers: ris.headers,
            request: r,
          );
        }),
      );
      return ObiettiviRepositorySupabase(db);
    }

    http.Response json(Object corpo, [int stato = 200]) => http.Response(
      jsonEncode(corpo),
      stato,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    Map<String, dynamic> riga(int kcal, String data) => {
      'id': 'o$kcal',
      'kcal': kcal,
      'proteine_g': 110,
      'carboidrati_g': 230.5,
      'grassi_g': 65,
      'data_inizio': data,
    };

    test(
      'corrente: l\'ultima per data, a parità la più recente creata',
      () async {
        final r = repo((_) => json(riga(2000, '2026-11-10')));
        final o = await r.corrente('paz-1');
        expect(o!.kcal, 2000);
        expect(o.carboidratiG, 230.5);
        expect(o.dal, DateTime(2026, 11, 10));
        final q = richieste.single.url.queryParameters;
        expect(richieste.single.url.path, '/rest/v1/obiettivi');
        expect(q['paziente_id'], 'eq.paz-1');
        expect(
          q['order'],
          'data_inizio.desc.nullslast,creato_il.desc.nullslast',
        );
        expect(q['limit'], '1');
      },
    );

    test('corrente senza righe restituisce null', () async {
      final r = repo((_) => json([]));
      // maybeSingle con lista vuota
      expect(await r.corrente('paz-1'), isNull);
    });

    test('imposta inserisce una nuova riga e avvisa i listener', () async {
      final r = repo((_) => json(riga(2100, '2026-11-25'), 201));
      var avvisi = 0;
      r.addListener(() => avvisi++);
      final o = await r.imposta(
        'paz-1',
        kcal: 2100,
        proteineG: 110,
        carboidratiG: 230.5,
        grassiG: 65,
      );
      expect(o.kcal, 2100);
      final ins = richieste.first;
      expect(ins.method, 'POST');
      expect(jsonDecode(ins.body), {
        'paziente_id': 'paz-1',
        'kcal': 2100,
        'proteine_g': 110.0,
        'carboidrati_g': 230.5,
        'grassi_g': 65.0,
      });
      expect(avvisi, 1);
    });

    test('permesso negato dalla RLS: errore chiaro, nessun avviso', () async {
      final r = repo(
        (_) => json({
          'code': '42501',
          'message': 'new row violates row-level security policy',
        }, 403),
      );
      var avvisi = 0;
      r.addListener(() => avvisi++);
      await expectLater(
        r.imposta(
          'altro',
          kcal: 2000,
          proteineG: 1,
          carboidratiG: 1,
          grassiG: 1,
        ),
        throwsA(isA<ErroreOperazione>()),
      );
      expect(avvisi, 0);
    });
  });

  group('Schermata Obiettivi (nutrizionista)', () {
    Future<DipendenzeFinte> avvia(
      WidgetTester tester, {
      Map<String, List<Obiettivi>>? iniziali,
    }) async {
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final dip = DipendenzeFinte(ruolo: Ruolo.nutrizionista);
      if (iniziali != null) {
        for (final e in iniziali.entries) {
          for (final o in e.value) {
            await dip.obiettivi.imposta(
              e.key,
              kcal: o.kcal,
              proteineG: o.proteineG,
              carboidratiG: o.carboidratiG,
              grassiG: o.grassiG,
            );
          }
        }
        dip.obiettivi.salvataggi = 0;
      }
      await tester.pumpWidget(CenatoApp(dip: dip.dip));
      await tester.pumpAndSettle();
      return dip;
    }

    Future<void> apri(WidgetTester tester, String paziente) async {
      await tester.tap(find.text(paziente));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Obiettivi nutrizionali'));
      await tester.pumpAndSettle();
    }

    Finder campo(String etichetta) => find.widgetWithText(TextField, etichetta);

    final ob = Obiettivi(
      kcal: 1800,
      proteineG: 95,
      carboidratiG: 210.5,
      grassiG: 60,
      dal: DateTime(2026, 11, 1),
    );

    testWidgets('SC_GP_4: imposto gli obiettivi di Marco e li ritrovo', (
      tester,
    ) async {
      final dip = await avvia(tester);
      await apri(tester, 'Marco');
      expect(
        find.textContaining('Non ci sono ancora obiettivi'),
        findsOneWidget,
      );

      await tester.enterText(campo('Calorie al giorno (kcal)'), '2000');
      await tester.enterText(campo('Proteine al giorno (g)'), '110');
      await tester.enterText(campo('Carboidrati al giorno (g)'), '230');
      await tester.enterText(campo('Grassi al giorno (g)'), '65');
      await tester.pump();
      expect(find.byKey(const Key('avviso-coerenza')), findsNothing);

      await tester.tap(find.text('Salva obiettivi'));
      await tester.pumpAndSettle();

      // Conferma e ritorno all'elenco
      expect(find.text('Obiettivi di Marco salvati.'), findsOneWidget);
      expect(find.text('Obiettivi nutrizionali'), findsNothing);
      final salvato = (await dip.obiettivi.corrente('p1'))!;
      expect(
        [
          salvato.kcal,
          salvato.proteineG,
          salvato.carboidratiG,
          salvato.grassiG,
        ],
        [2000, 110, 230, 65],
      );

      // Alla riapertura i valori sono precompilati
      await apri(tester, 'Marco');
      expect(
        tester
            .widget<TextField>(campo('Calorie al giorno (kcal)'))
            .controller!
            .text,
        '2000',
      );
      expect(
        tester
            .widget<TextField>(campo('Proteine al giorno (g)'))
            .controller!
            .text,
        '110',
      );
      expect(
        tester
            .widget<TextField>(campo('Carboidrati al giorno (g)'))
            .controller!
            .text,
        '230',
      );
      expect(
        tester
            .widget<TextField>(campo('Grassi al giorno (g)'))
            .controller!
            .text,
        '65',
      );
      expect(find.textContaining('In vigore dal'), findsOneWidget);
    });

    testWidgets('valori non validi sono rifiutati con messaggio', (
      tester,
    ) async {
      final dip = await avvia(tester);
      await apri(tester, 'Marco');

      await tester.enterText(campo('Calorie al giorno (kcal)'), '100');
      await tester.enterText(campo('Proteine al giorno (g)'), '-5');
      await tester.enterText(campo('Carboidrati al giorno (g)'), 'abc');
      await tester.tap(find.text('Salva obiettivi'));
      await tester.pumpAndSettle();

      expect(
        find.text('Le kcal devono essere tra 800 e 6000.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Proteine: un valore maggiore di 0'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Inserisci i grammi di carboidrati'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Inserisci i grammi di grassi'),
        findsOneWidget,
      );
      expect(await dip.obiettivi.corrente('p1'), isNull);
      // Resta sulla schermata
      expect(find.text('Salva obiettivi'), findsOneWidget);
    });

    testWidgets('kcal e macro incoerenti: avviso non bloccante', (
      tester,
    ) async {
      final dip = await avvia(tester);
      await apri(tester, 'Marco');

      await tester.enterText(campo('Calorie al giorno (kcal)'), '2500');
      await tester.enterText(campo('Proteine al giorno (g)'), '110');
      await tester.enterText(campo('Carboidrati al giorno (g)'), '230');
      await tester.enterText(campo('Grassi al giorno (g)'), '65');
      await tester.pump();
      expect(find.byKey(const Key('avviso-coerenza')), findsOneWidget);

      await tester.tap(find.text('Salva obiettivi'));
      await tester.pumpAndSettle();
      expect((await dip.obiettivi.corrente('p1'))!.kcal, 2500);
    });

    testWidgets('modifica: precompilato, nuova riga e storico', (tester) async {
      final dip = await avvia(
        tester,
        iniziali: {
          'p1': [ob],
        },
      );
      await apri(tester, 'Marco');
      expect(
        tester
            .widget<TextField>(campo('Carboidrati al giorno (g)'))
            .controller!
            .text,
        '210,5',
      );

      await tester.enterText(campo('Calorie al giorno (kcal)'), '1750');
      await tester.tap(find.text('Salva obiettivi'));
      await tester.pumpAndSettle();
      expect((await dip.obiettivi.storico('p1')).map((o) => o.kcal), [
        1750,
        1800,
      ]);

      await apri(tester, 'Marco');
      expect(find.text('Versioni precedenti'), findsOneWidget);
      expect(find.textContaining('1800 kcal'), findsOneWidget);
    });

    testWidgets('valori invariati: nessuna nuova riga nello storico', (
      tester,
    ) async {
      final dip = await avvia(
        tester,
        iniziali: {
          'p1': [ob],
        },
      );
      await apri(tester, 'Marco');
      await tester.tap(find.text('Salva obiettivi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nessuna modifica'), findsOneWidget);
      expect(dip.obiettivi.salvataggi, 0);
    });

    testWidgets('errore di rete al salvataggio: campi conservati, Riprova', (
      tester,
    ) async {
      final dip = await avvia(tester);
      await apri(tester, 'Marco');
      await tester.enterText(campo('Calorie al giorno (kcal)'), '2000');
      await tester.enterText(campo('Proteine al giorno (g)'), '110');
      await tester.enterText(campo('Carboidrati al giorno (g)'), '230');
      await tester.enterText(campo('Grassi al giorno (g)'), '65');

      dip.obiettivi.nonRaggiungibile = true;
      await tester.tap(find.text('Salva obiettivi'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('messaggio-errore')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(campo('Calorie al giorno (kcal)'))
            .controller!
            .text,
        '2000',
      );

      dip.obiettivi.nonRaggiungibile = false;
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect((await dip.obiettivi.corrente('p1'))!.kcal, 2000);
    });

    testWidgets('errore di rete al caricamento: Riprova', (tester) async {
      tester.view.physicalSize = const Size(1080, 4200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final dip = DipendenzeFinte(ruolo: Ruolo.nutrizionista);
      await tester.pumpWidget(CenatoApp(dip: dip.dip));
      await tester.pumpAndSettle();
      dip.obiettivi.nonRaggiungibile = true;
      await apri(tester, 'Marco');
      expect(find.text('Riprova'), findsOneWidget);
      expect(find.text('Salva obiettivi'), findsNothing);

      dip.obiettivi.nonRaggiungibile = false;
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect(find.text('Salva obiettivi'), findsOneWidget);
    });

    testWidgets('320 dp e testo al 200%: nessun overflow', (tester) async {
      tester.view.physicalSize = const Size(640, 1280);
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final dip = DipendenzeFinte(ruolo: Ruolo.nutrizionista);
      await dip.obiettivi.imposta(
        'p1',
        kcal: 2000,
        proteineG: 110,
        carboidratiG: 230,
        grassiG: 65,
      );
      await dip.obiettivi.imposta(
        'p1',
        kcal: 3000,
        proteineG: 110,
        carboidratiG: 230,
        grassiG: 65,
      );
      await tester.pumpWidget(CenatoApp(dip: dip.dip));
      await tester.pumpAndSettle();
      await apri(tester, 'Marco');
      expect(tester.takeException(), isNull);
      final scorrevole = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      // Con 3000 kcal e questi macro compare anche l'avviso di coerenza.
      await tester.scrollUntilVisible(
        find.byKey(const Key('avviso-coerenza')),
        300,
        scrollable: scorrevole,
      );
      await tester.scrollUntilVisible(
        find.text('Versioni precedenti'),
        300,
        scrollable: scorrevole,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('i pazienti archiviati non hanno il pulsante Obiettivi', (
      tester,
    ) async {
      await avvia(tester);
      await tester.tap(find.text('Archiviati'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Luca'));
      await tester.pumpAndSettle();
      expect(find.text('Obiettivi nutrizionali'), findsNothing);
    });
  });
}
