import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cenato/data/finto/dipendenze_finte.dart';
import 'package:cenato/data/finto/piani_repository_finto.dart';
import 'package:cenato/data/supabase/piani_repository_supabase.dart';
import 'package:cenato/domain/modelli/alimento.dart';
import 'package:cenato/domain/modelli/obiettivi.dart';
import 'package:cenato/domain/modelli/piano_alimentare.dart';
import 'package:cenato/domain/modelli/profilo.dart';
import 'package:cenato/domain/regole/calcoli_piano.dart';
import 'package:cenato/domain/repository/pazienti_repository.dart';
import 'package:cenato/main.dart';

import 'font_reali.dart';

Alimento _latte() => const Alimento(
  id: 'a-latte',
  nome: 'Latte parzialmente scremato',
  kcal100g: 46,
  proteine100g: 3.4,
  carboidrati100g: 4.9,
  grassi100g: 1.6,
  fonte: FonteAlimento.personalizzato,
);

Alimento _avena() => const Alimento(
  id: 'a-avena',
  nome: 'Fiocchi di avena',
  kcal100g: 372,
  proteine100g: 13.5,
  carboidrati100g: 60,
  grassi100g: 7,
  fonte: FonteAlimento.personalizzato,
);

Alimento _fette() => const Alimento(
  id: 'a-fette',
  nome: 'Fette biscottate',
  kcal100g: 410,
  proteine100g: 11,
  carboidrati100g: 72,
  grassi100g: 6,
  fonte: FonteAlimento.personalizzato,
);

/// Lunedì: colazione con latte 200 g e avena 40 g (alternativa: fette 35 g).
PianoAlimentare _pianoLunedi() => PianoAlimentare(
  dataInizio: DateTime(2026, 11, 25),
  giorni: [
    GiornoPiano(
      giornoSettimana: 1,
      pasti: [
        PastoPiano(
          tipo: TipoPasto.colazione,
          orario: '08:00',
          voci: [
            VocePiano(alimento: _latte(), quantitaG: 200),
            VocePiano(
              alimento: _avena(),
              quantitaG: 40,
              alternative: [
                AlternativaPiano(alimento: _fette(), quantitaG: 35),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await caricaFontReali();
  });

  // ------------------------------------------------------------------ calcoli
  group('Calcoli del piano (RF_GP_2)', () {
    test('kcal e macro di una voce: valori per 100 g × quantità / 100', () {
      final m = macroVoce(_latte(), 200);
      expect(m.kcal, 92);
      expect(m.proteineG, 6.8);
      expect(m.carboidratiG, 9.8);
      expect(m.grassiG, 3.2);
      final a = macroVoce(_avena(), 40);
      expect(a.kcal, 148.8);
      expect(a.proteineG, 5.4);
      expect(a.carboidratiG, 24);
      expect(a.grassiG, 2.8);
    });

    test('arrotondamento a un decimale come nel database', () {
      // 13,5 g/100 g × 33 g = 4,455 → 4,5 (come round(…, 1) di Postgres)
      expect(macroVoce(_avena(), 33).proteineG, 4.5);
      expect(arrotonda1(0.04), 0);
      expect(arrotonda1(148.84), 148.8);
    });

    test('alimento incompleto o quantità zero: nessun macro', () {
      const incompleto = Alimento(
        nome: 'Misterioso',
        kcal100g: 100,
        fonte: FonteAlimento.openFoodFacts,
      );
      expect(macroVoce(incompleto, 100), Macro.zero);
      expect(macroVoce(_latte(), 0), Macro.zero);
      expect(macroVoce(_latte(), -5), Macro.zero);
    });

    test('pasto e giorno sommano le voci', () {
      final giorno = _pianoLunedi().giorni.first;
      final colazione = macroPasto(giorno.pasti.first);
      expect(colazione.kcal, closeTo(240.8, 1e-9));
      expect(colazione.proteineG, closeTo(12.2, 1e-9));
      expect(macroGiorno(giorno), colazione);
      expect(macroGiorno(const GiornoPiano(giornoSettimana: 2)), Macro.zero);
    });

    test('le alternative non entrano nei totali', () {
      // L'alternativa (fette 35 g = 143,5 kcal) non è nel pasto previsto.
      expect(
        macroPasto(_pianoLunedi().giorni.first.pasti.first).kcal,
        closeTo(240.8, 1e-9),
      );
    });
  });

  group('Scostamento dagli obiettivi (RF_GP_16)', () {
    final obiettivi = Obiettivi(
      kcal: 2000,
      proteineG: 110,
      carboidratiG: 230,
      grassiG: 65,
      dal: DateTime(2026, 11, 1),
    );

    test('SC_GP_1: giornata a +60 kcal, in linea con la tolleranza', () {
      final s = scostamento(
        const Macro(kcal: 2060, proteineG: 110, carboidratiG: 230, grassiG: 65),
        obiettivi,
      );
      expect(s.kcal.assoluto, 60);
      expect(s.kcal.relativo, closeTo(0.03, 1e-9));
      expect(s.kcal.stato, StatoScostamento.inLinea);
      expect(s.inLinea, isTrue);
    });

    test('la tolleranza è il 10%: 2200 in linea, 2201 sopra, 1799 sotto', () {
      StatoScostamento stato(double kcal) =>
          scostamento(Macro(kcal: kcal), obiettivi).kcal.stato;
      expect(stato(2200), StatoScostamento.inLinea);
      expect(stato(2201), StatoScostamento.sopra);
      expect(stato(1800), StatoScostamento.inLinea);
      expect(stato(1799), StatoScostamento.sotto);
      expect(tolleranzaScostamento, 0.10);
    });

    test('un macro fuori obiettivo toglie "in linea" al giorno', () {
      final s = scostamento(
        const Macro(kcal: 2000, proteineG: 60, carboidratiG: 230, grassiG: 65),
        obiettivi,
      );
      expect(s.kcal.stato, StatoScostamento.inLinea);
      expect(s.proteine.stato, StatoScostamento.sotto);
      expect(s.inLinea, isFalse);
    });

    test(
      'obiettivo zero: nessuno scarto relativo, niente divisione per zero',
      () {
        const v = ScostamentoValore(totale: 10, obiettivo: 0);
        expect(v.relativo, 0);
      },
    );
  });

  group('Validazione', () {
    test('quantità (UC_GP_2, flusso 4.1)', () {
      expect(validaQuantita('150'), isNull);
      expect(validaQuantita('12,5'), isNull);
      expect(validaQuantita(' 200 '), isNull);
      expect(validaQuantita(''), isNotNull);
      expect(validaQuantita('abc'), isNotNull);
      expect(validaQuantita('0'), 'La quantità deve essere maggiore di zero.');
      expect(
        validaQuantita('-10'),
        'La quantità deve essere maggiore di zero.',
      );
      expect(validaQuantita('5001'), contains('5000'));
      expect(validaQuantita('5000'), isNull);
      expect(validaQuantita('1,25'), 'Usa al massimo un decimale.');
      expect(leggiQuantita('12,5'), 12.5);
      expect(quantitaRapideG, [50, 100, 150, 200]);
    });

    test('piano: giorni senza pasti e pasti senza alimenti bloccano il salvataggio', () {
      expect(
        problemiDelPiano(PianoAlimentare(dataInizio: DateTime(2026, 11, 25)))
            .single
            .tipo,
        TipoProblema.pianoSenzaGiorni,
      );
      final vuoto = PianoAlimentare(dataInizio: DateTime(2026, 11, 25))
          .aggiungiGiorno(1, [TipoPasto.colazione, TipoPasto.cena])
          .aggiungiGiorno(2, const []);
      final problemi = problemiDelPiano(vuoto);
      expect(problemi.map((p) => p.tipo), [
        TipoProblema.pastoSenzaAlimenti,
        TipoProblema.pastoSenzaAlimenti,
        TipoProblema.giornoSenzaPasti,
      ]);
      expect(
        problemi.first.messaggio,
        'Lunedì, colazione: pasto senza alimenti. Completalo o eliminalo.',
      );
      expect(problemiDelPiano(_pianoLunedi()), isEmpty);
    });
  });

  // ------------------------------------------------------------- modifiche
  group('Modifiche del piano (immutabili)', () {
    test('giorni in ordine di settimana, senza duplicati', () {
      var p = PianoAlimentare(dataInizio: DateTime(2026, 11, 25));
      p = p.aggiungiGiorno(3, [TipoPasto.pranzo]).aggiungiGiorno(1, [
        TipoPasto.cena,
      ]);
      expect(p.giorni.map((g) => g.giornoSettimana), [1, 3]);
      expect(p.aggiungiGiorno(1, [TipoPasto.cena]), same(p));
      expect(p.rimuoviGiorno(1).giorni.map((g) => g.giornoSettimana), [3]);
    });

    test('un pasto nuovo va al suo posto nella giornata', () {
      var p = PianoAlimentare(dataInizio: DateTime(2026, 11, 25))
          .aggiungiGiorno(1, [
            TipoPasto.colazione,
            TipoPasto.pranzo,
            TipoPasto.cena,
          ]);
      p = p
          .aggiungiPasto(1, TipoPasto.spuntino)
          .aggiungiPasto(1, TipoPasto.merenda);
      expect(p.giorno(1)!.pasti.map((x) => x.tipo), [
        TipoPasto.colazione,
        TipoPasto.spuntino,
        TipoPasto.pranzo,
        TipoPasto.merenda,
        TipoPasto.cena,
      ]);
      // più spuntini nello stesso giorno sono ammessi
      p = p.aggiungiPasto(1, TipoPasto.spuntino);
      expect(
        p.giorno(1)!.pasti.where((x) => x.tipo == TipoPasto.spuntino),
        hasLength(2),
      );
    });

    test(
      'voci: aggiungi, cambia quantità, sposta, togli; l\'originale non cambia',
      () {
        final originale = _pianoLunedi();
        final pasto = originale.giorno(1)!.pasti.first;
        final avena = pasto.voci[1];

        final p1 = originale.aggiornaQuantita(
          1,
          pasto.chiave,
          avena.chiave,
          60,
        );
        expect(p1.giorno(1)!.pasti.first.voci[1].quantitaG, 60);
        expect(originale.giorno(1)!.pasti.first.voci[1].quantitaG, 40);
        // le alternative restano attaccate alla voce
        expect(p1.giorno(1)!.pasti.first.voci[1].alternative, hasLength(1));

        final p2 = originale.spostaVoce(1, pasto.chiave, 0, 1);
        expect(p2.giorno(1)!.pasti.first.voci.map((v) => v.alimento.nome), [
          'Fiocchi di avena',
          'Latte parzialmente scremato',
        ]);
        // uno spostamento fuori intervallo non cambia l'ordine
        expect(
          originale
              .spostaVoce(1, pasto.chiave, 0, 9)
              .giorno(1)!
              .pasti
              .first
              .voci
              .map((v) => v.alimento.nome),
          ['Latte parzialmente scremato', 'Fiocchi di avena'],
        );

        final p3 = originale.rimuoviVoce(1, pasto.chiave, avena.chiave);
        expect(p3.giorno(1)!.pasti.first.voci, hasLength(1));

        final p4 = originale.aggiungiVoce(
          1,
          pasto.chiave,
          VocePiano(alimento: _fette(), quantitaG: 30),
        );
        expect(p4.giorno(1)!.pasti.first.voci, hasLength(3));
        expect(originale.giorno(1)!.pasti.first.voci, hasLength(2));
      },
    );

    test('orario del pasto', () {
      final p = _pianoLunedi();
      final k = p.giorno(1)!.pasti.first.chiave;
      expect(
        p.impostaOrario(1, k, '07:30').giorno(1)!.pasti.first.orario,
        '07:30',
      );
      expect(p.impostaOrario(1, k, null).giorno(1)!.pasti.first.orario, isNull);
    });
  });

  // -------------------------------------------------------- repository finto
  group('Repository finto: versioni (RF_GP_7)', () {
    test(
      'ogni salvataggio è una nuova versione; la vecchia è superata',
      () async {
        final r = PianiRepositoryFinto();
        expect(await r.corrente('p1'), isNull);
        final v1 = await r.salva('p1', _pianoLunedi());
        final v2 = await r.salva('p1', _pianoLunedi());
        expect([v1.versione, v2.versione], [1, 2]);
        expect((await r.corrente('p1'))!.versione, 2);
        final storico = await r.versioni('p1');
        expect(storico.map((v) => '${v.versione} ${v.stato.valoreDb}'), [
          '2 corrente',
          '1 superato',
        ]);
        expect((await r.versione(v1.id!)).stato, StatoPiano.superato);
        expect(await r.corrente('p2'), isNull);
      },
    );

    test('un piano non valido non crea nulla', () async {
      final r = PianiRepositoryFinto();
      await expectLater(
        r.salva('p1', PianoAlimentare(dataInizio: DateTime(2026, 11, 25))),
        throwsA(isA<ErroreOperazione>()),
      );
      expect(r.salvataggi, 0);
      expect(await r.versioni('p1'), isEmpty);
    });

    test('avvisa i listener a ogni salvataggio', () async {
      final r = PianiRepositoryFinto();
      var n = 0;
      r.addListener(() => n++);
      await r.salva('p1', _pianoLunedi());
      expect(n, 1);
    });
  });

  // --------------------------------------------------------------- Supabase
  group('Supabase (finto PostgREST)', () {
    late List<http.Request> richieste;

    PianiRepositorySupabase repo(http.Response Function(http.Request) f) {
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
      return PianiRepositorySupabase(db);
    }

    http.Response json(Object corpo, [int stato = 200]) => http.Response(
      jsonEncode(corpo),
      stato,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    Map<String, dynamic> alimento(String id, String nome, num kcal) => {
      'id': id,
      'nome': nome,
      'marca': null,
      'codice_barre': null,
      'kcal_100g': kcal,
      'proteine_100g': 10,
      'carboidrati_100g': 20,
      'grassi_100g': 5,
      'fonte': 'personalizzato',
    };

    Map<String, dynamic> rigaPiano() => {
      'id': 'piano-2',
      'versione': 2,
      'stato': 'corrente',
      'data_inizio': '2026-11-25',
      'creato_il': '2026-11-25T10:00:00+00:00',
      'giorni': [
        {
          'id': 'g2',
          'giorno_settimana': 2,
          'pasti': [
            {
              'id': 'p-cena',
              'tipo': 'cena',
              'orario': '20:00:00',
              'ordine': 2,
              'voci_pasto': [],
            },
            {
              'id': 'p-col',
              'tipo': 'colazione',
              'orario': null,
              'ordine': 1,
              'voci_pasto': [
                {
                  'id': 'v2',
                  'quantita_g': '40.0',
                  'ordine': 2,
                  'alimento': alimento('a2', 'Avena', 372),
                  'alternative': [
                    {
                      'id': 'alt1',
                      'quantita_g': 35,
                      'alimento': alimento('a3', 'Fette', 410),
                    },
                  ],
                },
                {
                  'id': 'v1',
                  'quantita_g': 200,
                  'ordine': 1,
                  'alimento': alimento('a1', 'Latte', 46),
                  'alternative': [],
                },
              ],
            },
          ],
        },
        {'id': 'g1', 'giorno_settimana': 1, 'pasti': []},
      ],
    };

    test('lettura: struttura annidata ordinata e orari "HH:mm"', () async {
      final r = repo((_) => json(rigaPiano()));
      final p = (await r.corrente('paz-1'))!;
      expect(richieste.single.url.path, '/rest/v1/piani');
      expect(richieste.single.url.queryParameters['paziente_id'], 'eq.paz-1');
      expect(richieste.single.url.queryParameters['stato'], 'eq.corrente');
      expect(p.versione, 2);
      expect(p.stato, StatoPiano.corrente);
      expect(p.dataInizio, DateTime(2026, 11, 25));
      expect(p.giorni.map((g) => g.giornoSettimana), [1, 2]);
      final pasti = p.giorno(2)!.pasti;
      expect(pasti.map((x) => x.tipo), [TipoPasto.colazione, TipoPasto.cena]);
      expect(pasti.first.orario, isNull);
      expect(pasti.last.orario, '20:00');
      expect(pasti.first.voci.map((v) => v.alimento.nome), ['Latte', 'Avena']);
      expect(pasti.first.voci.last.quantitaG, 40);
      expect(pasti.first.voci.last.alternative.single.alimento.nome, 'Fette');
    });

    test('corrente: nessuna riga → null', () async {
      final r = repo((_) => json([]));
      expect(await r.corrente('paz-1'), isNull);
    });

    test('versioni: dalla più recente', () async {
      final r = repo(
        (_) => json([
          {
            'id': 'p2',
            'versione': 2,
            'stato': 'corrente',
            'data_inizio': '2026-11-25',
            'creato_il': '2026-11-25T10:00:00+00:00',
          },
          {
            'id': 'p1',
            'versione': 1,
            'stato': 'superato',
            'data_inizio': '2026-11-01',
            'creato_il': '2026-11-01T10:00:00+00:00',
          },
        ]),
      );
      final v = await r.versioni('paz-1');
      expect(v.map((x) => x.versione), [2, 1]);
      expect(v.last.stato, StatoPiano.superato);
      expect(
        richieste.single.url.queryParameters['order'],
        'versione.desc.nullslast',
      );
    });

    test(
      'salva: RPC transazionale con la struttura, poi rilegge la versione',
      () async {
        final r = repo((q) {
          if (q.url.path.endsWith('/rpc/salva_piano')) return json('piano-2');
          return json(rigaPiano());
        });
        var avvisi = 0;
        r.addListener(() => avvisi++);
        final salvato = await r.salva('paz-1', _pianoLunedi());

        final rpc = richieste.first;
        expect(rpc.method, 'POST');
        expect(rpc.url.path, '/rest/v1/rpc/salva_piano');
        final corpo = jsonDecode(rpc.body) as Map<String, dynamic>;
        expect(corpo['p_paziente'], 'paz-1');
        expect(corpo['p_data_inizio'], '2026-11-25');
        final giorni = (corpo['p_struttura'] as Map)['giorni'] as List;
        expect(giorni.single['giorno'], 1);
        final pasto = giorni.single['pasti'].single as Map;
        expect(pasto['tipo'], 'colazione');
        expect(pasto['orario'], '08:00');
        final voci = pasto['voci'] as List;
        expect(voci[0], {'alimento_id': 'a-latte', 'quantita_g': 200.0});
        expect(voci[1]['alimento_id'], 'a-avena');
        expect(voci[1]['alternative'], [
          {'alimento_id': 'a-fette', 'quantita_g': 35.0},
        ]);
        // kcal e macro non partono: li ricalcola il database
        expect(rpc.body, isNot(contains('kcal')));

        expect(richieste.last.url.queryParameters['id'], 'eq.piano-2');
        expect(salvato.versione, 2);
        expect(avvisi, 1);
      },
    );

    test(
      'salva: errore del database (pasto senza alimenti) con il suo messaggio',
      () async {
        final r = repo(
          (_) => json({
            'code': 'CN022',
            'message': 'Un pasto è senza alimenti: completalo o eliminalo.',
          }, 400),
        );
        var avvisi = 0;
        r.addListener(() => avvisi++);
        await expectLater(
          r.salva('paz-1', _pianoLunedi()),
          throwsA(
            isA<ErroreOperazione>().having(
              (e) => e.messaggio,
              'messaggio',
              'Un pasto è senza alimenti: completalo o eliminalo.',
            ),
          ),
        );
        expect(avvisi, 0);
      },
    );

    test('struttura per il salvataggio senza alternative non ha la chiave', () {
      final s = strutturaPerSalvataggio(_pianoLunedi());
      final voci =
          (((s['giorni'] as List).single['pasti'] as List).single['voci']
              as List);
      expect((voci[0] as Map).containsKey('alternative'), isFalse);
      expect((voci[1] as Map).containsKey('alternative'), isTrue);
    });
  });

  // ------------------------------------------------------------ schermate
  group('Editor del piano (nutrizionista)', () {
    Future<DipendenzeFinte> avvia(
      WidgetTester tester, {
      bool obiettivi = true,
      bool pianoEsistente = false,
      Size dimensione = const Size(432, 1680),
      double scala = 1,
    }) async {
      tester.view.physicalSize = dimensione * 2.5;
      tester.view.devicePixelRatio = 2.5;
      tester.platformDispatcher.textScaleFactorTestValue = scala;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final dip = DipendenzeFinte(ruolo: Ruolo.nutrizionista);
      if (obiettivi) {
        await dip.obiettivi.imposta(
          'p1',
          kcal: 2000,
          proteineG: 110,
          carboidratiG: 230,
          grassiG: 65,
        );
        dip.obiettivi.salvataggi = 0;
      }
      if (pianoEsistente) {
        await dip.piani.salva('p1', _pianoLunedi());
        dip.piani.salvataggi = 0;
      }
      await tester.pumpWidget(CenatoApp(dip: dip.dip));
      await tester.pumpAndSettle();
      return dip;
    }

    Future<void> apriEditor(
      WidgetTester tester, [
      String nome = 'Marco',
    ]) async {
      await tester.tap(find.text(nome));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Piano alimentare'));
      await tester.pumpAndSettle();
    }

    Future<void> salvaConferma(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Salva e assegna'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salva e assegna'));
      await tester.pumpAndSettle();
    }

    String testoTotale(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const Key('totale-kcal')))
        .textSpan!
        .toPlainText();

    Future<void> scegliAlimentoCercando(
      WidgetTester tester,
      String ricerca,
      String nome,
    ) async {
      await tester.tap(find.text('Aggiungi alimento').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), ricerca);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text(nome).first);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'SC_GP_1: nuovo piano, alimenti con quantità rapida, salvataggio v1',
      (tester) async {
        final dip = await avvia(tester);
        await dip.alimenti.creaPersonalizzato(
          nome: 'Latte parzialmente scremato',
          kcal100g: 46,
          proteine100g: 3.4,
          carboidrati100g: 4.9,
          grassi100g: 1.6,
        );
        await dip.alimenti.creaPersonalizzato(
          nome: 'Fiocchi di avena',
          kcal100g: 372,
          proteine100g: 13.5,
          carboidrati100g: 60,
          grassi100g: 7,
        );
        await apriEditor(tester);
        expect(find.text('Nuovo piano per Marco'), findsOneWidget);
        // solo il lunedì, solo la colazione
        for (final g in ['Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom']) {
          await tester.tap(find.text(g));
        }
        for (final t in ['Spuntino', 'Pranzo', 'Cena']) {
          await tester.tap(find.text(t));
        }
        await tester.pump();
        await tester.tap(find.text('Crea piano'));
        await tester.pumpAndSettle();

        // totali visibili da subito, con gli obiettivi di Marco
        expect(testoTotale(tester), contains('0 kcal'));
        expect(testoTotale(tester), contains('su 2000 di obiettivo'));
        expect(find.text('Colazione'), findsOneWidget);

        // latte 200 ml con la quantità rapida
        await scegliAlimentoCercando(
          tester,
          'latte',
          'Latte parzialmente scremato',
        );
        await tester.tap(find.byKey(const Key('quantita-rapida-200')));
        await tester.pump();
        expect(
          tester.widget<Text>(find.byKey(const Key('anteprima-quantita'))).data,
          contains('92 kcal'),
        );
        await tester.tap(find.text('Aggiungi'));
        await tester.pumpAndSettle();
        expect(testoTotale(tester), contains('92 kcal'));

        // cereali 40 g scritti a mano (con la virgola non serve: intero)
        await scegliAlimentoCercando(tester, 'avena', 'Fiocchi di avena');
        await tester.enterText(
          find.widgetWithText(TextField, 'Quantità (g)'),
          '40',
        );
        await tester.pump();
        await tester.tap(find.text('Aggiungi'));
        await tester.pumpAndSettle();
        expect(testoTotale(tester), contains('241 kcal'));
        // scostamento dall'obiettivo: -1759 kcal, fuori obiettivo
        expect(find.textContaining('-1759 kcal (-88%)'), findsOneWidget);
        expect(find.textContaining('fuori obiettivo'), findsOneWidget);
        expect(find.text('Proteine 12,2 / 110 g'), findsOneWidget);

        // salvataggio con conferma
        await salvaConferma(tester);
        expect(
          find.textContaining(
            'Piano salvato: versione 1. Marco lo vede nella sezione Dieta.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Piano alimentare'),
          findsNothing,
        ); // tornati all'elenco
        final v1 = (await dip.piani.corrente('p1'))!;
        expect(v1.versione, 1);
        expect(v1.giorni.single.giornoSettimana, 1);
        expect(v1.giorni.single.pasti.single.voci.map((v) => v.quantitaG), [
          200,
          40,
        ]);
        expect(macroGiorno(v1.giorni.single).kcal, closeTo(240.8, 1e-9));
      },
    );

    testWidgets(
      'modifica: parte dal piano in uso, nuova versione, storico consultabile',
      (tester) async {
        final dip = await avvia(tester, pianoEsistente: true);
        await apriEditor(tester);
        // niente impostazione: il piano in uso è già lì, con le alternative
        expect(find.text('Nuovo piano per Marco'), findsNothing);
        expect(find.text('Fiocchi di avena'), findsOneWidget);
        expect(
          find.textContaining('Alternative: Fette biscottate 35 g'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('riga-versione')), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('riga-versione'))).data,
          startsWith('Versione 2 · dal '),
        );

        // avena da 40 a 60 g
        await tester.tap(find.text('Fiocchi di avena'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Quantità (g)'))
              .controller!
              .text,
          '40',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Quantità (g)'),
          '60',
        );
        await tester.tap(find.text('Salva quantità'));
        await tester.pumpAndSettle();
        expect(testoTotale(tester), contains('315 kcal')); // 92 + 223,2

        await salvaConferma(tester);
        expect(
          find.textContaining('Piano salvato: versione 2'),
          findsOneWidget,
        );
        final v2 = (await dip.piani.corrente('p1'))!;
        expect(v2.versione, 2);
        expect(v2.giorno(1)!.pasti.first.voci[1].quantitaG, 60);
        // le alternative sono passate nella nuova versione
        expect(v2.giorno(1)!.pasti.first.voci[1].alternative, hasLength(1));
        final storico = await dip.piani.versioni('p1');
        expect(storico.map((v) => v.stato), [
          StatoPiano.corrente,
          StatoPiano.superato,
        ]);

        // lo storico dall'editor: si vede, non si ripristina
        await apriEditor(tester);
        await tester.tap(find.byTooltip('Versioni del piano'));
        await tester.pumpAndSettle();
        expect(find.text('Versione 2 · In uso'), findsOneWidget);
        expect(find.text('Versione 1 · Superata'), findsOneWidget);
        await tester.tap(find.text('Versione 1 · Superata'));
        await tester.pumpAndSettle();
        expect(find.text('Fiocchi di avena'), findsOneWidget);
        expect(
          find.textContaining('40 g · 149 kcal'),
          findsOneWidget,
        ); // la v1 aveva 40 g
        expect(find.text('Aggiungi alimento'), findsNothing); // sola lettura
        expect(find.text('Ripristina'), findsNothing);
      },
    );

    testWidgets(
      'pasto senza alimenti: il salvataggio chiede di completarlo o eliminarlo',
      (tester) async {
        final dip = await avvia(tester);
        await apriEditor(tester);
        for (final g in ['Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom']) {
          await tester.tap(find.text(g));
        }
        for (final t in ['Spuntino', 'Pranzo']) {
          await tester.tap(find.text(t));
        }
        await tester.pump();
        await tester.tap(find.text('Crea piano'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Salva e assegna'));
        await tester.pumpAndSettle();
        expect(find.text('Il piano non è completo'), findsOneWidget);
        expect(
          find.textContaining(
            'Lunedì, colazione: pasto senza alimenti. Completalo o eliminalo.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Ho capito'));
        await tester.pumpAndSettle();
        expect(
          find.text('Pasto senza alimenti: aggiungine uno o eliminalo.'),
          findsOneWidget,
        );
        expect(dip.piani.salvataggi, 0);

        // eliminare il pasto vuoto non chiede conferma; resta la cena vuota
        await tester.tap(find.byTooltip('Opzioni del pasto').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elimina pasto'));
        await tester.pumpAndSettle();
        expect(find.text('Colazione'), findsNothing);
        expect(find.text('Cena'), findsOneWidget);
      },
    );

    testWidgets(
      'molti pasti vuoti: l\'avviso ne elenca pochi e riassume gli altri',
      (tester) async {
        await avvia(tester);
        await apriEditor(tester);
        // 7 giorni × 4 pasti = 28 pasti senza alimenti
        await tester.tap(find.text('Crea piano'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Salva e assegna'));
        await tester.pumpAndSettle();
        expect(find.text('Il piano non è completo'), findsOneWidget);
        expect(find.textContaining('pasto senza alimenti'), findsNWidgets(4));
        expect(find.text('…e altri 24 da completare.'), findsOneWidget);
      },
    );

    testWidgets(
      'quantità non valida: messaggio sul campo, il pasto non cambia',
      (tester) async {
        await avvia(tester, pianoEsistente: true);
        await apriEditor(tester);
        await tester.tap(find.text('Fiocchi di avena'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Quantità (g)'),
          '0',
        );
        await tester.tap(find.text('Salva quantità'));
        await tester.pumpAndSettle();
        expect(
          find.text('La quantità deve essere maggiore di zero.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Quantità (g)'),
          '',
        );
        await tester.tap(find.text('Salva quantità'));
        await tester.pumpAndSettle();
        expect(find.text('Inserisci la quantità in grammi.'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('anteprima-quantita'))).data,
          contains('Indica la quantità'),
        );
      },
    );

    testWidgets(
      'uscita con modifiche non salvate: avviso; senza modifiche: nessun avviso',
      (tester) async {
        final dip = await avvia(tester, pianoEsistente: true);

        // nessuna modifica → si esce subito
        await apriEditor(tester);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Uscire senza salvare?'), findsNothing);
        expect(find.text('Piano alimentare'), findsNothing);

        // con una modifica → avviso; Annulla resta, Esci perde le modifiche
        await apriEditor(tester);
        await tester.tap(find.byTooltip('Togli Fiocchi di avena'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Uscire senza salvare?'), findsOneWidget);
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();
        expect(find.text('Piano di Marco'), findsOneWidget);
        expect(find.text('Fiocchi di avena'), findsNothing);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Esci'));
        await tester.pumpAndSettle();
        expect(find.text('Piano di Marco'), findsNothing);
        expect(dip.piani.salvataggi, 0);
        expect(
          (await dip.piani.corrente('p1'))!.giorno(1)!.pasti.first.voci,
          hasLength(2),
        );
      },
    );

    testWidgets(
      'errore di rete al salvataggio: il piano resta, Riprova lo salva',
      (tester) async {
        final dip = await avvia(tester, pianoEsistente: true);
        await apriEditor(tester);
        await tester.tap(find.byTooltip('Togli Fiocchi di avena'));
        await tester.pumpAndSettle();

        dip.piani.nonRaggiungibile = true;
        await salvaConferma(tester);
        expect(find.byKey(const Key('messaggio-errore')), findsOneWidget);
        expect(find.text('Piano di Marco'), findsOneWidget);
        expect(
          find.text('Fiocchi di avena'),
          findsNothing,
        ); // modifica conservata
        expect(dip.piani.salvataggi, 0);

        dip.piani.nonRaggiungibile = false;
        await tester.tap(find.text('Riprova'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salva e assegna')); // conferma
        await tester.pumpAndSettle();
        expect(dip.piani.salvataggi, 1);
        expect(
          (await dip.piani.corrente('p1'))!.giorno(1)!.pasti.first.voci,
          hasLength(1),
        );
      },
    );

    testWidgets('errore di rete al caricamento: Riprova', (tester) async {
      final dip = await avvia(tester);
      dip.piani.nonRaggiungibile = true;
      await apriEditor(tester);
      expect(find.text('Riprova'), findsOneWidget);
      dip.piani.nonRaggiungibile = false;
      await tester.tap(find.text('Riprova'));
      await tester.pumpAndSettle();
      expect(find.text('Crea piano'), findsOneWidget);
    });

    testWidgets(
      'obiettivi mancanti: invito a impostarli, l\'editor non è bloccato',
      (tester) async {
        await avvia(tester, obiettivi: false);
        await apriEditor(tester);
        expect(find.byKey(const Key('banner-obiettivi')), findsOneWidget);
        expect(find.text('Crea piano'), findsOneWidget); // non bloccato

        // si impostano e al ritorno il banner sparisce
        await tester.tap(find.text('Imposta obiettivi'));
        await tester.pumpAndSettle();
        expect(find.text('Obiettivi nutrizionali'), findsWidgets);
        Finder campo(String e) => find.widgetWithText(TextField, e);
        await tester.enterText(campo('Calorie al giorno (kcal)'), '2000');
        await tester.enterText(campo('Proteine al giorno (g)'), '110');
        await tester.enterText(campo('Carboidrati al giorno (g)'), '230');
        await tester.enterText(campo('Grassi al giorno (g)'), '65');
        await tester.tap(find.text('Salva obiettivi'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('banner-obiettivi')), findsNothing);
        expect(find.text('Crea piano'), findsOneWidget);

        // senza obiettivi l'editor mostra solo i totali, senza scostamento
        await tester.tap(find.text('Crea piano'));
        await tester.pumpAndSettle();
        expect(testoTotale(tester), contains('su 2000 di obiettivo'));
      },
    );

    testWidgets('senza obiettivi i totali non hanno scostamento', (
      tester,
    ) async {
      await avvia(tester, obiettivi: false, pianoEsistente: true);
      await apriEditor(tester);
      expect(find.byKey(const Key('banner-obiettivi')), findsOneWidget);
      expect(find.byKey(const Key('scostamento-kcal')), findsNothing);
      expect(testoTotale(tester), '241 kcal');
    });

    testWidgets('giorni e pasti: aggiungi un giorno, un pasto, toglili', (
      tester,
    ) async {
      await avvia(tester, pianoEsistente: true);
      await apriEditor(tester);

      await tester.tap(find.byTooltip('Giorni del piano'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aggiungi un giorno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Martedì').last);
      await tester.pumpAndSettle();
      expect(find.text('Mar'), findsOneWidget); // nuovo giorno attivo
      expect(find.text('Colazione'), findsOneWidget); // stessi tipi del lunedì
      expect(find.text('Nessun alimento ancora.'), findsOneWidget);

      await tester.tap(find.text('Aggiungi pasto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Merenda'));
      await tester.pumpAndSettle();
      expect(find.text('Merenda'), findsOneWidget);

      await tester.tap(find.byTooltip('Giorni del piano'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Togli martedì'));
      await tester.pumpAndSettle();
      expect(find.text('Mar'), findsNothing);
      expect(find.text('Lun'), findsOneWidget);
    });

    testWidgets(
      'togliere un alimento aggiorna subito i totali; riordino con la maniglia',
      (tester) async {
        final dip = await avvia(tester, pianoEsistente: true);
        await apriEditor(tester);
        // riordino: l'avena sopra il latte
        final latteY = tester
            .getTopLeft(find.text('Latte parzialmente scremato'))
            .dy;
        final avenaY = tester.getTopLeft(find.text('Fiocchi di avena')).dy;
        expect(latteY, lessThan(avenaY));
        await tester.drag(
          find.byIcon(Icons.drag_handle).first,
          const Offset(0, 300),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('Fiocchi di avena')).dy,
          lessThan(
            tester.getTopLeft(find.text('Latte parzialmente scremato')).dy,
          ),
        );
        await salvaConferma(tester);
        final ordine = (await dip.piani.corrente('p1'))!
            .giorno(1)!
            .pasti
            .first
            .voci
            .map((v) => v.alimento.nome);
        expect(ordine, ['Fiocchi di avena', 'Latte parzialmente scremato']);

        await apriEditor(tester);
        await tester.tap(find.byTooltip('Togli Fiocchi di avena'));
        await tester.pumpAndSettle();
        expect(testoTotale(tester), contains('92 kcal'));
      },
    );

    testWidgets('i pazienti archiviati non hanno il piano da modificare', (
      tester,
    ) async {
      await avvia(tester);
      await tester.tap(find.text('Archiviati'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Luca'));
      await tester.pumpAndSettle();
      expect(find.text('Piano alimentare'), findsNothing);
    });

    testWidgets('320 dp e testo al 200%: nessun overflow', (tester) async {
      await avvia(
        tester,
        pianoEsistente: true,
        dimensione: const Size(320, 640),
        scala: 2,
      );
      await apriEditor(tester);
      expect(tester.takeException(), isNull);
      final scorrevole = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Aggiungi pasto'),
        300,
        scrollable: scorrevole,
      );
      expect(tester.takeException(), isNull);
      // il foglio della quantità, con testo grande
      await tester.scrollUntilVisible(
        find.text('Fiocchi di avena'),
        -300,
        scrollable: scorrevole,
      );
      await tester.tap(find.text('Fiocchi di avena'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('320 dp, testo normale: totali fissi in alto', (tester) async {
      await avvia(
        tester,
        pianoEsistente: true,
        dimensione: const Size(320, 640),
      );
      await apriEditor(tester);
      expect(tester.takeException(), isNull);
      final y = tester.getTopLeft(find.byKey(const Key('riepilogo-giorno'))).dy;
      await tester.drag(find.byType(ListView).first, const Offset(0, -200));
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const Key('riepilogo-giorno'))).dy,
        y,
      );
    });
  });
}
