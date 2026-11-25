import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cenato/data/finto/dipendenze_finte.dart';
import 'package:cenato/data/finto/modelli_repository_finto.dart';
import 'package:cenato/data/finto/piani_repository_finto.dart';
import 'package:cenato/data/supabase/modelli_repository_supabase.dart';
import 'package:cenato/data/supabase/piani_repository_supabase.dart';
import 'package:cenato/domain/modelli/alimento.dart';
import 'package:cenato/domain/modelli/modello_piano.dart';
import 'package:cenato/domain/modelli/piano_alimentare.dart';
import 'package:cenato/domain/modelli/profilo.dart';
import 'package:cenato/domain/regole/calcoli_piano.dart';
import 'package:cenato/domain/repository/pazienti_repository.dart';
import 'package:cenato/main.dart';

import 'font_reali.dart';

/// Scheda "Alternative, giorno tipo con copia, pasti salvati e modelli"
/// (RF_GP_6, RF_GP_9, RF_GP_13, RF_GP_14, RF_GP_15; UC_GP_1, UC_GP_2; SD_1).

Alimento _alimento(
  String id,
  String nome,
  double k,
  double p,
  double c,
  double g,
) => Alimento(
  id: id,
  nome: nome,
  kcal100g: k,
  proteine100g: p,
  carboidrati100g: c,
  grassi100g: g,
  fonte: FonteAlimento.personalizzato,
);

final _latte = _alimento(
  'a-latte',
  'Latte parzialmente scremato',
  46,
  3.4,
  4.9,
  1.6,
);
final _avena = _alimento('a-avena', 'Fiocchi di avena', 372, 13.5, 60, 7);
final _fette = _alimento('a-fette', 'Fette biscottate', 410, 11, 72, 6);
final _pane = _alimento('a-pane', 'Pane tostato', 270, 9, 50, 3);

/// Lunedì: colazione con latte 200 g e avena 40 g (alternativa: fette 35 g).
/// Gli alimenti si possono passare (con gli id della cache) o si usano i
/// predefiniti.
PianoAlimentare _pianoLunedi({
  Alimento? latte,
  Alimento? avena,
  Alimento? fette,
}) => PianoAlimentare(
  dataInizio: DateTime(2026, 11, 25),
  giorni: [
    GiornoPiano(
      giornoSettimana: 1,
      pasti: [
        PastoPiano(
          tipo: TipoPasto.colazione,
          orario: '08:00',
          voci: [
            VocePiano(alimento: latte ?? _latte, quantitaG: 200),
            VocePiano(
              alimento: avena ?? _avena,
              quantitaG: 40,
              alternative: [
                AlternativaPiano(alimento: fette ?? _fette, quantitaG: 35),
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

  // ---------------------------------------------------------------- dominio
  group('Alternative (RF_GP_6)', () {
    test('si impostano per voce, le altre voci non cambiano', () {
      final p = _pianoLunedi();
      final pasto = p.giorno(1)!.pasti.first;
      final latte = pasto.voci[0];
      final nuovo = p.impostaAlternative(1, pasto.chiave, latte.chiave, [
        AlternativaPiano(alimento: _pane, quantitaG: 40),
        AlternativaPiano(alimento: _fette, quantitaG: 30),
      ]);
      final voci = nuovo.giorno(1)!.pasti.first.voci;
      expect(voci[0].alternative.map((a) => a.alimento.nome), [
        'Pane tostato',
        'Fette biscottate',
      ]);
      expect(voci[1].alternative, hasLength(1)); // avena invariata
      expect(p.giorno(1)!.pasti.first.voci[0].alternative, isEmpty);
      // nessuna alternativa: si può anche svuotare
      expect(
        nuovo
            .impostaAlternative(1, pasto.chiave, latte.chiave, const [])
            .giorno(1)!
            .pasti
            .first
            .voci[0]
            .alternative,
        isEmpty,
      );
    });

    test('il confronto con l\'originale è la differenza di kcal e macro', () {
      final avena = _pianoLunedi().giorno(1)!.pasti.first.voci[1];
      final d = differenzaAlternativa(avena, avena.alternative.first);
      // fette 35 g = 143,5 kcal contro avena 40 g = 148,8
      expect(d.kcal, closeTo(-5.3, 1e-9));
      expect(d.proteineG, closeTo(3.9 - 5.4, 1e-9));
      expect((const Macro(kcal: 10) - const Macro(kcal: 4)).kcal, 6);
    });

    test('le alternative non entrano nei totali del pasto', () {
      final pasto = _pianoLunedi().giorno(1)!.pasti.first;
      expect(macroPasto(pasto).kcal, closeTo(240.8, 1e-9));
    });
  });

  group('Copia del giorno (RF_GP_13)', () {
    PianoAlimentare conLunediEMartediVuoto() =>
        _pianoLunedi().aggiungiGiorno(2, [TipoPasto.colazione]);

    test('copia profonda: pasti, voci e alternative con chiavi nuove', () {
      final p = _pianoLunedi();
      final copia = p.copiaGiorno(1, [2, 3, 4, 5]);
      expect(copia.giorni.map((g) => g.giornoSettimana), [1, 2, 3, 4, 5]);
      final origine = copia.giorno(1)!.pasti.first;
      for (final g in [2, 3, 4, 5]) {
        final pasto = copia.giorno(g)!.pasti.first;
        expect(pasto.tipo, TipoPasto.colazione);
        expect(pasto.orario, '08:00');
        expect(pasto.voci.map((v) => v.quantitaG), [200, 40]);
        expect(
          pasto.voci[1].alternative.single.alimento.nome,
          'Fette biscottate',
        );
        // chiavi nuove: una copia vera, non un riferimento
        expect(pasto.chiave, isNot(origine.chiave));
        expect(pasto.voci[0].chiave, isNot(origine.voci[0].chiave));
        expect(macroGiorno(copia.giorno(g)!), macroGiorno(copia.giorno(1)!));
      }
      // l'origine e il piano di partenza non cambiano
      expect(p.giorni, hasLength(1));
      expect(copia.giorno(1), same(p.giorno(1)));
    });

    test('un giorno che ha già alimenti viene sostituito', () {
      var p = conLunediEMartediVuoto();
      final martedi = p.giorno(2)!.pasti.first;
      p = p.aggiungiVoce(
        2,
        martedi.chiave,
        VocePiano(alimento: _pane, quantitaG: 10),
      );
      expect(p.giorniConAlimenti([1, 2, 3]), [1, 2]);
      final sostituito = p.copiaGiorno(1, [2]);
      expect(sostituito.giorno(2)!.pasti, hasLength(1));
      expect(
        sostituito.giorno(2)!.pasti.first.voci.map((v) => v.alimento.nome),
        ['Latte parzialmente scremato', 'Fiocchi di avena'],
      );
    });

    test('copiare su sé stesso o da un giorno che non c\'è non fa nulla', () {
      final p = _pianoLunedi();
      expect(p.copiaGiorno(1, [1]).giorni, hasLength(1));
      expect(p.copiaGiorno(1, [1]).giorno(1), same(p.giorno(1)));
      expect(p.copiaGiorno(4, [5]), same(p));
    });

    test(
      'giorniConAlimenti: giorni con soli pasti vuoti o nuovi non contano',
      () {
        final p = conLunediEMartediVuoto();
        expect(p.giorno(2)!.pasti, hasLength(1)); // pasto vuoto
        expect(p.giorniConAlimenti([1, 2, 3]), [1]);
        expect(p.copiaGiorno(1, [2]).giorniConAlimenti([2]), [2]);
      },
    );
  });

  group('Modelli: codifica del contenuto (RF_GP_9)', () {
    test(
      'un pasto va e torna con alimenti, quantità, alternative e orario',
      () {
        final pasto = _pianoLunedi().giorno(1)!.pasti.first;
        final json = jsonDecode(
          jsonEncode(contenutoDaPasto(pasto)),
        ) as Map<String, dynamic>;
        final ritorno = pastoDaContenuto(json);
        expect(ritorno.tipo, TipoPasto.colazione);
        expect(ritorno.orario, '08:00');
        expect(ritorno.voci.map((v) => v.alimento.nome), [
          'Latte parzialmente scremato',
          'Fiocchi di avena',
        ]);
        expect(ritorno.voci[1].alimento.kcal100g, 372);
        expect(ritorno.voci[1].alimento.id, 'a-avena');
        expect(ritorno.voci[1].alternative.single.quantitaG, 35);
        expect(macroPasto(ritorno), macroPasto(pasto));
        // chiavi nuove: aprire un modello due volte dà due copie diverse
        expect(ritorno.chiave, isNot(pasto.chiave));
        expect(pastoDaContenuto(json).chiave, isNot(ritorno.chiave));
      },
    );

    test('un piano va e torna, giorni in ordine, con la data indicata', () {
      final piano = _pianoLunedi().copiaGiorno(1, [3, 2]);
      final json = jsonDecode(
        jsonEncode(contenutoDaPiano(piano)),
      ) as Map<String, dynamic>;
      final ritorno = pianoDaContenuto(json, DateTime(2027, 1, 4));
      expect(ritorno.dataInizio, DateTime(2027, 1, 4));
      expect(ritorno.giorni.map((g) => g.giornoSettimana), [1, 2, 3]);
      expect(macroGiorno(ritorno.giorno(3)!), macroGiorno(piano.giorno(3)!));
      expect(ritorno.id, isNull); // non è una versione salvata
    });

    test('contenuto non leggibile: FormatException', () {
      expect(() => pastoDaContenuto({}), throwsFormatException);
      expect(
        () => pastoDaContenuto({'tipo': 'cena', 'voci': 'x'}),
        throwsFormatException,
      );
      expect(
        () => pastoDaContenuto({
          'tipo': 'cena',
          'voci': [
            {
              'alimento': {'nome': 'X', 'fonte': 'personalizzato'},
              'quantita_g': 0,
            },
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => pianoDaContenuto({'giorni': 3}, DateTime(2026)),
        throwsFormatException,
      );
      expect(
        () => pianoDaContenuto({
          'giorni': [
            {
              'giorno': 1,
              'pasti': ['x'],
            },
          ],
        }, DateTime(2026)),
        throwsFormatException,
      );
    });

    test('descrizione per gli elenchi', () {
      final pasto = _pianoLunedi().giorno(1)!.pasti.first;
      ModelloPiano m(TipoModello t, Map<String, dynamic> c) =>
          ModelloPiano(id: 'm', nome: 'N', tipo: t, contenuto: c);
      expect(
        m(TipoModello.pasto, contenutoDaPasto(pasto)).descrizione,
        'Colazione · 2 alimenti',
      );
      expect(
        m(TipoModello.piano, contenutoDaPiano(_pianoLunedi())).descrizione,
        '1 giorno · 1 pasto',
      );
      expect(
        m(
          TipoModello.piano,
          contenutoDaPiano(_pianoLunedi().copiaGiorno(1, [2, 3])),
        ).descrizione,
        '3 giorni · 3 pasti',
      );
      expect(
        m(TipoModello.pasto, {'x': 1}).descrizione,
        'Contenuto non leggibile',
      );
    });

    test('nome del modello: da 1 a 120 caratteri', () {
      expect(validaNomeModello('Colazione'), isNull);
      expect(validaNomeModello('  '), 'Dai un nome al modello.');
      expect(validaNomeModello('x' * 121), contains('120'));
      expect(validaNomeModello('x' * 120), isNull);
    });

    test('un pasto inserito dal modello va al suo posto ed è una copia', () {
      var p = PianoAlimentare(dataInizio: DateTime(2026, 11, 25))
          .aggiungiGiorno(1, [TipoPasto.pranzo, TipoPasto.cena]);
      final modello = _pianoLunedi().giorno(1)!.pasti.first;
      p = p.inserisciPasto(1, modello);
      expect(p.giorno(1)!.pasti.map((x) => x.tipo), [
        TipoPasto.colazione,
        TipoPasto.pranzo,
        TipoPasto.cena,
      ]);
      expect(p.giorno(1)!.pasti.first.chiave, isNot(modello.chiave));
      expect(p.giorno(1)!.pasti.first.voci[1].alternative, hasLength(1));
    });
  });

  // ------------------------------------------------------------ repository
  group('Repository finto: modelli', () {
    test('salva, elenca dal più recente, elimina; avvisa i listener', () async {
      final r = ModelliRepositoryFinto();
      var n = 0;
      r.addListener(() => n++);
      final pasto = _pianoLunedi().giorno(1)!.pasti.first;
      final a = await r.salvaPasto('  Colazione tipo ', pasto);
      final b = await r.salvaPasto('Altra', pasto);
      await r.salvaPiano('Settimana', _pianoLunedi());
      expect(a.nome, 'Colazione tipo');
      expect((await r.elenco(TipoModello.pasto)).map((m) => m.nome), [
        'Altra',
        'Colazione tipo',
      ]);
      expect((await r.elenco(TipoModello.piano)).map((m) => m.nome), [
        'Settimana',
      ]);
      await r.elimina(b.id);
      expect((await r.elenco(TipoModello.pasto)).map((m) => m.nome), [
        'Colazione tipo',
      ]);
      expect(n, 4);
    });

    test('nome non valido e rete assente: errore, nulla salvato', () async {
      final r = ModelliRepositoryFinto();
      final pasto = _pianoLunedi().giorno(1)!.pasti.first;
      await expectLater(
        r.salvaPasto('  ', pasto),
        throwsA(isA<ErroreOperazione>()),
      );
      r.nonRaggiungibile = true;
      await expectLater(
        r.salvaPasto('X', pasto),
        throwsA(isA<ErroreOperazione>()),
      );
      await expectLater(
        r.elenco(TipoModello.pasto),
        throwsA(isA<ErroreOperazione>()),
      );
      r.nonRaggiungibile = false;
      expect(await r.elenco(TipoModello.pasto), isEmpty);
    });

    test(
      'un modello è una copia: cambiare il piano dopo non lo cambia',
      () async {
        final r = ModelliRepositoryFinto();
        final piano = _pianoLunedi();
        final m = await r.salvaPiano('Settimana', piano);
        final pasto = piano.giorno(1)!.pasti.first;
        // il piano cambia dopo il salvataggio
        final cambiato = piano.aggiornaQuantita(
          1,
          pasto.chiave,
          pasto.voci[0].chiave,
          500,
        );
        expect(cambiato.giorno(1)!.pasti.first.voci[0].quantitaG, 500);
        expect(
          m.piano(DateTime(2026)).giorno(1)!.pasti.first.voci[0].quantitaG,
          200,
        );
        // e il piano creato dal modello può cambiare senza toccarlo
        final dalModello = m.piano(DateTime(2026));
        final p2 = dalModello.giorno(1)!.pasti.first;
        dalModello.aggiornaQuantita(1, p2.chiave, p2.voci[0].chiave, 999);
        expect(
          m.piano(DateTime(2026)).giorno(1)!.pasti.first.voci[0].quantitaG,
          200,
        );
      },
    );
  });

  group('Repository finto: alternativePerPasto (SD_1)', () {
    test(
      'solo le alternative del pasto, con la voce che sostituiscono',
      () async {
        final r = PianiRepositoryFinto();
        // lunedì con in più una cena: voce con alternativa
        var p = _pianoLunedi().aggiungiPasto(1, TipoPasto.cena);
        final cena = p.giorno(1)!.pasti.last;
        p = p.aggiungiVoce(
          1,
          cena.chiave,
          VocePiano(
            alimento: _pane,
            quantitaG: 80,
            alternative: [AlternativaPiano(alimento: _fette, quantitaG: 60)],
          ),
        );
        final salvato = await r.salva('p1', p);
        final colazione = salvato.giorno(1)!.pasti.first;
        final ammesse = await r.alternativePerPasto(colazione.chiave);
        expect(ammesse, hasLength(1));
        expect(ammesse.single.alimento.nome, 'Fette biscottate');
        expect(ammesse.single.alimentoVoce.nome, 'Fiocchi di avena');
        expect(ammesse.single.quantitaVoceG, 40);
        expect(ammesse.single.id, isNotEmpty);
        expect(
          (await r.alternativePerPasto(salvato.giorno(1)!.pasti.last.chiave))
              .single
              .alimento
              .nome,
          'Fette biscottate',
        );
        expect(await r.alternativePerPasto('non-esiste'), isEmpty);
      },
    );
  });

  // -------------------------------------------------------------- Supabase
  group('Supabase (finto PostgREST)', () {
    late List<http.Request> richieste;

    SupabaseClient client(http.Response Function(http.Request) f) {
      richieste = [];
      return SupabaseClient(
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
    }

    http.Response json(Object corpo, [int stato = 200]) => http.Response(
      jsonEncode(corpo),
      stato,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    Map<String, dynamic> riga(
      String id,
      String nome,
      TipoModello t,
      Map<String, dynamic> c,
    ) => {
      'id': id,
      'nome': nome,
      'tipo': t.valoreDb,
      'contenuto': c,
      'creato_il': '2026-11-25T10:00:00+00:00',
    };

    final pasto = _pianoLunedi().giorno(1)!.pasti.first;

    test('elenco: per tipo, dal più recente, contenuto leggibile', () async {
      final r = ModelliRepositorySupabase(
        client(
          (_) => json([
            riga(
              'm1',
              'Colazione tipo',
              TipoModello.pasto,
              contenutoDaPasto(pasto),
            ),
          ]),
        ),
        idUtente: () => 'nut-1',
      );
      final m = await r.elenco(TipoModello.pasto);
      expect(richieste.single.url.path, '/rest/v1/modelli_piano');
      expect(richieste.single.url.queryParameters['tipo'], 'eq.pasto');
      expect(
        richieste.single.url.queryParameters['order'],
        'creato_il.desc.nullslast',
      );
      expect(m.single.nome, 'Colazione tipo');
      expect(m.single.pasto.voci, hasLength(2));
      expect(m.single.descrizione, 'Colazione · 2 alimenti');
    });

    test(
      'salva: inserisce a nome del nutrizionista con il contenuto',
      () async {
        final contenuto = contenutoDaPasto(pasto);
        final r = ModelliRepositorySupabase(
          client(
            (_) => json(
              riga('m2', 'Mia colazione', TipoModello.pasto, contenuto),
              201,
            ),
          ),
          idUtente: () => 'nut-1',
        );
        var avvisi = 0;
        r.addListener(() => avvisi++);
        final m = await r.salvaPasto('  Mia colazione ', pasto);
        final corpo = jsonDecode(richieste.single.body) as Map<String, dynamic>;
        expect(richieste.single.method, 'POST');
        expect(corpo['nutrizionista_id'], 'nut-1');
        expect(corpo['nome'], 'Mia colazione');
        expect(corpo['tipo'], 'pasto');
        expect(corpo['contenuto']['tipo'], 'colazione');
        expect(m.id, 'm2');
        expect(avvisi, 1);
      },
    );

    test('salva un piano modello', () async {
      final r = ModelliRepositorySupabase(
        client(
          (_) => json(
            riga(
              'm3',
              'Settimana',
              TipoModello.piano,
              contenutoDaPiano(_pianoLunedi()),
            ),
            201,
          ),
        ),
        idUtente: () => 'nut-1',
      );
      final m = await r.salvaPiano('Settimana', _pianoLunedi());
      expect(jsonDecode(richieste.single.body)['tipo'], 'piano');
      expect(m.piano(DateTime(2026)).giorni, hasLength(1));
    });

    test('nome vuoto, nessuna sessione e rifiuto della RLS: errori chiari, nulla scritto', () async {
      final r = ModelliRepositorySupabase(
        client((_) => json({}, 201)),
        idUtente: () => 'nut-1',
      );
      await expectLater(
        r.salvaPasto(' ', pasto),
        throwsA(isA<ErroreOperazione>()),
      );
      expect(richieste, isEmpty);
      final senza = ModelliRepositorySupabase(
        client((_) => json({}, 201)),
        idUtente: () => null,
      );
      await expectLater(
        senza.salvaPasto('X', pasto),
        throwsA(
          isA<ErroreOperazione>().having((e) => e.codice, 'codice', 'sessione'),
        ),
      );
      final negato = ModelliRepositorySupabase(
        client(
          (_) => json({'code': '42501', 'message': 'row-level security'}, 403),
        ),
        idUtente: () => 'nut-1',
      );
      await expectLater(
        negato.salvaPasto('X', pasto),
        throwsA(isA<ErroreOperazione>()),
      );
    });

    test('elimina: DELETE sull\'id', () async {
      final r = ModelliRepositorySupabase(
        client((_) => http.Response('', 204)),
        idUtente: () => 'nut-1',
      );
      var avvisi = 0;
      r.addListener(() => avvisi++);
      await r.elimina('m9');
      expect(richieste.single.method, 'DELETE');
      expect(richieste.single.url.queryParameters['id'], 'eq.m9');
      expect(avvisi, 1);
    });

    Map<String, dynamic> alim(String id, String nome) => {
      'id': id,
      'nome': nome,
      'kcal_100g': 100,
      'proteine_100g': 10,
      'carboidrati_100g': 10,
      'grassi_100g': 1,
      'fonte': 'personalizzato',
    };

    test(
      'alternativePerPasto: voci del pasto con le alternative e i loro id',
      () async {
        final r = PianiRepositorySupabase(
          client(
            (_) => json([
              {
                'id': 'v1',
                'quantita_g': 40,
                'ordine': 1,
                'alimento': alim('a1', 'Avena'),
                'alternative': [
                  {
                    'id': 'alt-1',
                    'quantita_g': 35,
                    'alimento': alim('a2', 'Fette'),
                  },
                  {
                    'id': 'alt-2',
                    'quantita_g': '30.0',
                    'alimento': alim('a3', 'Pane'),
                  },
                ],
              },
              {
                'id': 'v2',
                'quantita_g': 200,
                'ordine': 2,
                'alimento': alim('a4', 'Latte'),
                'alternative': [],
              },
            ]),
          ),
        );
        final a = await r.alternativePerPasto('pasto-1');
        expect(richieste.single.url.path, '/rest/v1/voci_pasto');
        expect(richieste.single.url.queryParameters['pasto_id'], 'eq.pasto-1');
        expect(a.map((x) => x.id), ['alt-1', 'alt-2']);
        expect(a.map((x) => x.voceId), ['v1', 'v1']);
        expect(a.first.alimentoVoce.nome, 'Avena');
        expect(a.first.quantitaVoceG, 40);
        expect(a.last.quantitaG, 30);
      },
    );
  });

  // ------------------------------------------------------------- schermate
  group('Editor: alternative, copia, modelli', () {
    Future<DipendenzeFinte> avvia(
      WidgetTester tester, {
      Size dimensione = const Size(432, 1680),
      double scala = 1,
    }) async {
      tester.view.physicalSize = dimensione * 2.5;
      tester.view.devicePixelRatio = 2.5;
      tester.platformDispatcher.textScaleFactorTestValue = scala;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final dip = DipendenzeFinte(ruolo: Ruolo.nutrizionista);
      for (final id in ['p1', 'p2', 'p3']) {
        await dip.obiettivi.imposta(
          id,
          kcal: 2000,
          proteineG: 110,
          carboidratiG: 230,
          grassiG: 65,
        );
      }
      // alimenti nella cache (con i loro id), come nell'uso reale: il piano di
      // Marco usa gli stessi alimenti che la ricerca ritrova
      Future<Alimento> inCache(Alimento a) => dip.alimenti.creaPersonalizzato(
        nome: a.nome,
        kcal100g: a.kcal100g!,
        proteine100g: a.proteine100g!,
        carboidrati100g: a.carboidrati100g!,
        grassi100g: a.grassi100g!,
      );
      final latte = await inCache(_latte);
      final avena = await inCache(_avena);
      final fette = await inCache(_fette);
      await inCache(_pane);
      await dip.piani.salva(
        'p1',
        _pianoLunedi(latte: latte, avena: avena, fette: fette),
      );
      dip.piani.salvataggi = 0;
      await tester.pumpWidget(CenatoApp(dip: dip.dip));
      await tester.pumpAndSettle();
      return dip;
    }

    Future<void> apriEditor(WidgetTester tester, String nome) async {
      await tester.tap(find.text(nome));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Piano alimentare'));
      await tester.pumpAndSettle();
    }

    Future<void> cercaEScegli(
      WidgetTester tester,
      String ricerca,
      String nome,
    ) async {
      await tester.enterText(find.byType(TextField), ricerca);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text(nome).first);
      await tester.pumpAndSettle();
    }

    Future<void> aggiungiAlternativa(
      WidgetTester tester,
      String ricerca,
      String nome,
      String grammi,
    ) async {
      await tester.tap(find.text('Aggiungi alternativa').last);
      await tester.pumpAndSettle();
      await cercaEScegli(tester, ricerca, nome);
      await tester.enterText(
        find.widgetWithText(TextField, 'Quantità (g)'),
        grammi,
      );
      await tester.pump();
      await tester.tap(find.text('Aggiungi'));
      await tester.pumpAndSettle();
    }

    Future<void> salvaConferma(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Salva e assegna'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salva e assegna'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'due alternative a una voce: il check-in avrà solo quelle (SD_1)',
      (tester) async {
        final dip = await avvia(tester);
        await apriEditor(tester, 'Marco');
        // il latte non ha alternative; l'avena ne ha già una
        expect(find.text('Aggiungi alternativa'), findsOneWidget);
        expect(find.text('Alternative (1)'), findsOneWidget);

        await tester.tap(find.text('Aggiungi alternativa'));
        await tester.pumpAndSettle();
        expect(find.text('Invece di'), findsOneWidget);
        expect(find.byKey(const Key('nessuna-alternativa')), findsOneWidget);

        await tester.tap(find.text('Aggiungi alternativa'));
        await tester.pumpAndSettle();
        await cercaEScegli(tester, 'fette', 'Fette biscottate');
        await tester.tap(find.byKey(const Key('quantita-rapida-50')));
        await tester.pump();
        await tester.tap(find.text('Aggiungi'));
        await tester.pumpAndSettle();
        // 50 g di fette = 205 kcal contro 92 kcal di 200 g di latte
        expect(
          find.textContaining(
            '50 g · 205 kcal · +113 kcal rispetto all\'originale',
          ),
          findsOneWidget,
        );

        await aggiungiAlternativa(tester, 'pane', 'Pane tostato', '40');
        expect(find.byKey(const Key('alternativa-0')), findsOneWidget);
        expect(find.byKey(const Key('alternativa-1')), findsOneWidget);
        expect(
          find.textContaining(
            '40 g · 108 kcal · +16 kcal rispetto all\'originale',
          ),
          findsOneWidget,
        );

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Alternative (2)'), findsOneWidget);
        expect(
          find.textContaining(
            'Alternative: Fette biscottate 50 g, Pane tostato 40 g',
          ),
          findsOneWidget,
        );

        await salvaConferma(tester);
        final salvato = (await dip.piani.corrente('p1'))!;
        final colazione = salvato.giorno(1)!.pasti.first;
        expect(colazione.voci[0].alternative.map((a) => a.alimento.nome), [
          'Fette biscottate',
          'Pane tostato',
        ]);
        // il metodo per il check-in: solo queste tre (2 del latte + 1 dell'avena)
        final ammesse = await dip.piani.alternativePerPasto(colazione.chiave);
        expect(ammesse.map((a) => a.alimento.nome), [
          'Fette biscottate',
          'Pane tostato',
          'Fette biscottate',
        ]);
        expect(ammesse.map((a) => a.alimentoVoce.nome), [
          'Latte parzialmente scremato',
          'Latte parzialmente scremato',
          'Fiocchi di avena',
        ]);
      },
    );

    testWidgets(
      'alternativa: stessa dell\'originale o già presente rifiutata; si può togliere e cambiare',
      (tester) async {
        await avvia(tester);
        await apriEditor(tester, 'Marco');
        await tester.tap(find.text('Alternative (1)'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('alternativa-0')), findsOneWidget);

        // già tra le alternative
        await tester.tap(find.text('Aggiungi alternativa'));
        await tester.pumpAndSettle();
        await cercaEScegli(tester, 'fette', 'Fette biscottate');
        expect(find.textContaining('è già tra le alternative'), findsOneWidget);
        expect(find.byKey(const Key('alternativa-1')), findsNothing);

        // cambia la quantità: 35 → 100 g (410 kcal)
        await tester.tap(find.byKey(const Key('alternativa-0')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Quantità (g)'))
              .controller!
              .text,
          '35',
        );
        await tester.tap(find.byKey(const Key('quantita-rapida-100')));
        await tester.pump();
        await tester.tap(find.text('Salva quantità'));
        await tester.pumpAndSettle();
        expect(find.textContaining('100 g · 410 kcal'), findsOneWidget);

        // togli
        await tester.tap(find.byTooltip('Togli Fette biscottate'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('nessuna-alternativa')), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Alternative (1)'), findsNothing);
        expect(find.text('Aggiungi alternativa'), findsNWidgets(2));
      },
    );

    testWidgets('alternativa uguale all\'alimento del pasto: rifiutata', (
      tester,
    ) async {
      await avvia(tester);
      await apriEditor(tester, 'Marco');
      await tester.tap(find.text('Alternative (1)')); // l'avena
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aggiungi alternativa'));
      await tester.pumpAndSettle();
      await cercaEScegli(tester, 'avena', 'Fiocchi di avena');
      expect(
        find.textContaining('è già l\'alimento del pasto'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('alternativa-1')), findsNothing);
    });

    testWidgets(
      'RF_GP_14: nell\'editor, a campo vuoto, preferiti e recenti in cima',
      (tester) async {
        final dip = await avvia(tester);
        final pane = (await dip.alimenti.recenti()).firstWhere(
          (a) => a.nome == 'Pane tostato',
        );
        await dip.alimenti.impostaPreferito(pane, true);
        await apriEditor(tester, 'Marco');
        await tester.tap(find.text('Aggiungi alimento').first);
        await tester.pumpAndSettle();
        expect(find.text('Preferiti'), findsOneWidget);
        expect(find.text('Usati di recente'), findsOneWidget);
        // il preferito sta sopra i recenti
        expect(
          tester.getTopLeft(find.text('Pane tostato')).dy,
          lessThan(tester.getTopLeft(find.text('Fette biscottate')).dy),
        );
        // si sceglie senza digitare e la quantità ha i chip rapidi (RF_GP_15)
        await tester.tap(find.text('Pane tostato'));
        await tester.pumpAndSettle();
        for (final g in quantitaRapideG) {
          expect(find.byKey(Key('quantita-rapida-$g')), findsOneWidget);
        }
      },
    );

    testWidgets('SC copia: lunedì su martedì–venerdì in pochi tocchi', (
      tester,
    ) async {
      final dip = await avvia(tester);
      await apriEditor(tester, 'Marco');
      await tester.tap(find.byTooltip('Giorni del piano'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copia lunedì su…'));
      await tester.pumpAndSettle();
      // Copia disattivato finché non si sceglie un giorno
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Copia'))
            .onPressed,
        isNull,
      );
      expect(find.text('Giorno nuovo'), findsNWidgets(6));
      for (final g in [2, 3, 4, 5]) {
        await tester.tap(find.byKey(Key('copia-giorno-$g')));
      }
      await tester.pump();
      await tester.tap(find.text('Copia'));
      await tester.pumpAndSettle();
      expect(find.text('Lunedì copiato su 4 giorni.'), findsOneWidget);
      for (final g in ['Lun', 'Mar', 'Mer', 'Gio', 'Ven']) {
        expect(find.text(g), findsOneWidget);
      }
      expect(find.text('Sab'), findsNothing);

      // il venerdì è uguale al lunedì, alternative comprese
      await tester.tap(find.text('Ven'));
      await tester.pumpAndSettle();
      expect(find.text('Latte parzialmente scremato'), findsOneWidget);
      expect(find.text('Alternative (1)'), findsOneWidget);
      expect(find.textContaining('241 kcal'), findsWidgets);

      await salvaConferma(tester);
      final v = (await dip.piani.corrente('p1'))!;
      expect(v.giorni.map((g) => g.giornoSettimana), [1, 2, 3, 4, 5]);
      for (final g in v.giorni) {
        expect(macroGiorno(g).kcal, closeTo(240.8, 1e-9));
        expect(g.pasti.single.voci[1].alternative, hasLength(1));
      }
    });

    testWidgets(
      'copia su un giorno che ha già alimenti: chiede di sostituire',
      (tester) async {
        await avvia(tester);
        await apriEditor(tester, 'Marco');

        Future<void> copiaLunediSuMartedi() async {
          await tester.tap(find.text('Lun'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Giorni del piano'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Copia lunedì su…'));
          await tester.pumpAndSettle();
        }

        // martedì nuovo, con un pasto vuoto: copiare non perde nulla, niente conferma
        await tester.tap(find.byTooltip('Giorni del piano'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Aggiungi un giorno'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Martedì').last);
        await tester.pumpAndSettle();
        expect(find.text('Nessun alimento ancora.'), findsOneWidget);
        await copiaLunediSuMartedi();
        expect(find.text('Vuoto'), findsOneWidget);
        await tester.tap(find.byKey(const Key('copia-giorno-2')));
        await tester.pump();
        await tester.tap(find.text('Copia'));
        await tester.pumpAndSettle();
        expect(find.text('Sostituire i pasti?'), findsNothing);

        // martedì ora ha gli alimenti: tolgo l'avena, così è diverso dal lunedì
        await tester.tap(find.text('Mar'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Togli Fiocchi di avena'));
        await tester.pumpAndSettle();
        expect(find.text('Fiocchi di avena'), findsNothing);

        // copiare di nuovo: ha alimenti → conferma
        await copiaLunediSuMartedi();
        expect(
          find.text('Ha già dei pasti: verranno sostituiti'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('copia-giorno-2')));
        await tester.pump();
        await tester.tap(find.text('Copia'));
        await tester.pumpAndSettle();
        expect(find.text('Sostituire i pasti?'), findsOneWidget);
        expect(find.textContaining('Martedì ha già dei pasti'), findsOneWidget);

        // Annulla: martedì resta senza avena
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mar'));
        await tester.pumpAndSettle();
        expect(find.text('Fiocchi di avena'), findsNothing);

        // Sostituisci: martedì torna uguale al lunedì
        await copiaLunediSuMartedi();
        await tester.tap(find.byKey(const Key('copia-giorno-2')));
        await tester.pump();
        await tester.tap(find.text('Copia'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sostituisci'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mar'));
        await tester.pumpAndSettle();
        expect(find.text('Fiocchi di avena'), findsOneWidget);
        expect(find.text('Alternative (1)'), findsOneWidget);
      },
    );

    testWidgets(
      'pasto salvato come modello e inserito nel piano di un altro paziente',
      (tester) async {
        final dip = await avvia(tester);
        await apriEditor(tester, 'Marco');
        await tester.tap(find.byTooltip('Opzioni del pasto'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salva come modello'));
        await tester.pumpAndSettle();
        // nome vuoto: messaggio
        await tester.enterText(find.byType(TextField), '');
        await tester.tap(find.text('Salva'));
        await tester.pumpAndSettle();
        expect(find.text('Dai un nome al modello.'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Colazione di Marco');
        await tester.tap(find.text('Salva'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            '«Colazione di Marco» salvato tra i pasti salvati.',
          ),
          findsOneWidget,
        );
        expect(
          (await dip.modelli.elenco(TipoModello.pasto)).single.nome,
          'Colazione di Marco',
        );

        // esco senza altre modifiche dal piano di Marco
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // Sara: piano nuovo con solo il pranzo del lunedì, poi il pasto salvato
        await apriEditor(tester, 'Sara');
        for (final g in ['Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom']) {
          await tester.tap(find.text(g));
        }
        for (final t in ['Colazione', 'Spuntino', 'Cena']) {
          await tester.tap(find.text(t));
        }
        await tester.pump();
        await tester.tap(find.text('Crea piano'));
        await tester.pumpAndSettle();
        expect(find.text('Pranzo'), findsOneWidget);

        await tester.tap(find.text('Da pasto salvato'));
        await tester.pumpAndSettle();
        expect(find.text('Pasti salvati'), findsOneWidget);
        expect(find.text('Colazione di Marco'), findsOneWidget);
        expect(find.text('Colazione · 2 alimenti'), findsOneWidget);
        await tester.tap(find.text('Colazione di Marco'));
        await tester.pumpAndSettle();

        // la colazione va prima del pranzo, con le sue alternative e i suoi totali
        expect(find.text('Colazione'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Colazione')).dy,
          lessThan(tester.getTopLeft(find.text('Pranzo')).dy),
        );
        expect(find.text('Alternative (1)'), findsOneWidget);
        expect(find.textContaining('241 kcal'), findsWidgets);

        // modificare il pasto nel piano di Sara non cambia il modello
        await tester.tap(find.text('Fiocchi di avena'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Quantità (g)'),
          '80',
        );
        await tester.tap(find.text('Salva quantità'));
        await tester.pumpAndSettle();
        final modello = (await dip.modelli.elenco(TipoModello.pasto)).single;
        expect(modello.pasto.voci[1].quantitaG, 40);
      },
    );

    testWidgets(
      'piano salvato come modello e piano nuovo da modello per un altro paziente',
      (tester) async {
        final dip = await avvia(tester);
        await apriEditor(tester, 'Marco');
        await tester.tap(find.byTooltip('Altre azioni'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Salva piano come modello'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Settimana tipo');
        await tester.tap(find.text('Salva'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('«Settimana tipo» salvato tra i piani modello.'),
          findsOneWidget,
        );
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // Paolo: nessun piano, parte dal modello
        await apriEditor(tester, 'Paolo');
        await tester.tap(find.text('Parti da un piano modello'));
        await tester.pumpAndSettle();
        expect(find.text('Piani modello'), findsOneWidget);
        expect(find.text('1 giorno · 1 pasto'), findsOneWidget);
        await tester.tap(find.text('Settimana tipo'));
        await tester.pumpAndSettle();
        expect(find.text('Latte parzialmente scremato'), findsOneWidget);
        expect(find.text('Alternative (1)'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('riga-versione'))).data,
          startsWith('Versione 1 · dal '),
        );

        await salvaConferma(tester);
        final paolo = (await dip.piani.corrente('p3'))!;
        expect(paolo.versione, 1);
        expect(paolo.giorno(1)!.pasti.single.voci.map((v) => v.quantitaG), [
          200,
          40,
        ]);
        // il piano di Marco è rimasto quello e il modello pure
        expect((await dip.piani.corrente('p1'))!.versione, 1);
        expect(
          (await dip.modelli.elenco(TipoModello.piano)).single.nome,
          'Settimana tipo',
        );
      },
    );

    testWidgets('un piano incompleto non si salva come modello', (
      tester,
    ) async {
      await avvia(tester);
      await apriEditor(tester, 'Paolo');
      await tester.tap(find.text('Crea piano'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Altre azioni'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salva piano come modello'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Completa il piano prima di salvarlo come modello.',
        ),
        findsOneWidget,
      );
      expect(find.text('Salva il piano come modello'), findsNothing);
    });

    testWidgets(
      'modelli: elenco vuoto, eliminazione con conferma, errore di rete',
      (tester) async {
        final dip = await avvia(tester);
        await apriEditor(tester, 'Paolo');
        await tester.tap(find.text('Parti da un piano modello'));
        await tester.pumpAndSettle();
        expect(find.text('Nessun piano modello'), findsOneWidget);
        await tester.tapAt(const Offset(10, 100)); // chiude il foglio
        await tester.pumpAndSettle();

        // due pasti salvati
        final pasto = _pianoLunedi().giorno(1)!.pasti.first;
        await dip.modelli.salvaPasto('Prima', pasto);
        await dip.modelli.salvaPasto('Seconda', pasto);
        await tester.tap(find.text('Crea piano'));
        await tester.pumpAndSettle();

        dip.modelli.nonRaggiungibile = true;
        await tester.tap(find.text('Da pasto salvato'));
        await tester.pumpAndSettle();
        expect(find.text('Riprova'), findsOneWidget);
        dip.modelli.nonRaggiungibile = false;
        await tester.tap(find.text('Riprova'));
        await tester.pumpAndSettle();
        expect(find.text('Seconda'), findsOneWidget);

        await tester.tap(find.byTooltip('Elimina Seconda'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            'I piani già creati con questo modello non cambiano.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();
        expect(find.text('Seconda'), findsOneWidget);
        await tester.tap(find.byTooltip('Elimina Seconda'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elimina').last);
        await tester.pumpAndSettle();
        expect(find.text('Seconda'), findsNothing);
        expect(find.text('Prima'), findsOneWidget);
        expect(
          (await dip.modelli.elenco(TipoModello.pasto)).map((m) => m.nome),
          ['Prima'],
        );
      },
    );

    testWidgets('modello non leggibile: avviso, il piano non cambia', (
      tester,
    ) async {
      final dip = await avvia(tester);
      await apriEditor(tester, 'Paolo');
      // un modello con contenuto rovinato
      final rovinato = await dip.modelli.salvaPiano('Rovinato', _pianoLunedi());
      (await dip.modelli.elenco(TipoModello.piano)).single.contenuto['giorni'] =
          'x';
      expect(rovinato.id, isNotEmpty);
      await tester.tap(find.text('Parti da un piano modello'));
      await tester.pumpAndSettle();
      expect(find.text('Contenuto non leggibile'), findsOneWidget);
      await tester.tap(find.text('Rovinato'));
      await tester.pumpAndSettle();
      expect(find.textContaining('non è leggibile'), findsOneWidget);
      expect(find.text('Crea piano'), findsOneWidget);
    });

    testWidgets(
      '320 dp e testo al 200%: alternative, copia e modelli senza overflow',
      (tester) async {
        final dip = await avvia(
          tester,
          dimensione: const Size(320, 640),
          scala: 2,
        );
        await dip.modelli.salvaPasto(
          'Colazione con un nome decisamente molto lungo ' * 2,
          _pianoLunedi().giorno(1)!.pasti.first,
        );
        await apriEditor(tester, 'Marco');
        expect(tester.takeException(), isNull);
        final scorrevole = find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Alternative (1)'),
          300,
          scrollable: scorrevole,
        );
        await tester.ensureVisible(find.text('Alternative (1)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alternative (1)'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Da pasto salvato'),
          300,
          scrollable: scorrevole,
        );
        await tester.ensureVisible(find.text('Da pasto salvato'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Da pasto salvato'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(10, 50));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byTooltip('Giorni del piano'),
          -300,
          scrollable: scorrevole,
        );
        await tester.ensureVisible(find.byTooltip('Giorni del piano'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Giorni del piano'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Copia lunedì su…'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
