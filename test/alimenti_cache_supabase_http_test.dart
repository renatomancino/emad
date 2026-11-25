import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cenato/data/supabase/alimenti_cache_supabase.dart';
import 'package:cenato/domain/modelli/alimento.dart';
import 'package:cenato/domain/repository/pazienti_repository.dart';

/// La cache su Supabase con un finto PostgREST: si controllano le richieste
/// che l'app spedisce (query, intestazioni, corpo) e come legge le risposte.
/// Le policy RLS si provano a parte, in `supabase/tests/`.
class _Server {
  _Server(this.gestore);

  /// Riceve la richiesta e restituisce la risposta (JSON).
  final http.Response Function(http.Request r) gestore;
  final richieste = <http.Request>[];

  Future<http.Response> chiama(http.Request r) async {
    richieste.add(r);
    final risposta = gestore(r);
    // Il client PostgREST legge `response.request`: va riportata.
    return http.Response.bytes(
      risposta.bodyBytes,
      risposta.statusCode,
      headers: risposta.headers,
      request: r,
    );
  }
}

http.Response _json(Object corpo, [int stato = 200]) => http.Response(
  jsonEncode(corpo),
  stato,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _riga(
  String id,
  String nome, {
  String? codice,
  String fonte = 'open_food_facts',
}) => {
  'id': id,
  'nome': nome,
  'marca': null,
  'codice_barre': codice,
  'kcal_100g': 250,
  'proteine_100g': 8,
  'carboidrati_100g': 49,
  'grassi_100g': 1.5,
  'fonte': fonte,
};

AlimentiCacheSupabase _cache(_Server s, {String? utente = 'nut-1'}) {
  final db = SupabaseClient(
    'https://prova.supabase.co',
    'chiave-anon',
    httpClient: MockClient(s.chiama),
  );
  return AlimentiCacheSupabase(db, idUtente: () => utente);
}

Alimento _off({String? codice = '1000000000001'}) => Alimento(
  nome: 'Pane integrale',
  codiceBarre: codice,
  kcal100g: 250,
  proteine100g: 8,
  carboidrati100g: 49,
  grassi100g: 1.5,
  fonte: FonteAlimento.openFoodFacts,
);

void main() {
  group('Ricerca per nome', () {
    test(
      'cerca con ilike sul nome (caratteri speciali resi letterali) e ordina',
      () async {
        final s = _Server((r) {
          if (r.url.path.endsWith('/alimenti')) {
            return _json([_riga('a1', 'Pane A'), _riga('a2', 'Pane B')]);
          }
          return _json([
            {
              'alimento_id': 'a2',
              'preferito': true,
              'ultimo_uso': '2026-01-01T00:00:00Z',
            },
          ]);
        });
        final trovati = await _cache(s).cercaPerNome('100%_pane');

        final ricerca = s.richieste.first;
        expect(ricerca.method, 'GET');
        expect(ricerca.url.path, '/rest/v1/alimenti');
        expect(ricerca.url.queryParameters['nome'], r'ilike.%100\%\_pane%');
        expect(ricerca.url.queryParameters['limit'], isNotNull);

        final uso = s.richieste.last;
        expect(uso.url.path, '/rest/v1/alimenti_nutrizionista');
        expect(uso.url.queryParameters['alimento_id'], 'in.("a1","a2")');

        // La stella porta Pane B in cima.
        expect(trovati.map((a) => a.nome), ['Pane B', 'Pane A']);
        expect(trovati.first.preferito, isTrue);
      },
    );

    test('senza risultati non interroga i recenti', () async {
      final s = _Server((r) => _json([]));
      expect(await _cache(s).cercaPerNome('xyz'), isEmpty);
      expect(s.richieste.length, 1);
    });

    test('un testo vuoto non fa richieste', () async {
      final s = _Server((r) => _json([]));
      expect(await _cache(s).cercaPerNome('  '), isEmpty);
      expect(s.richieste, isEmpty);
    });
  });

  group('Salvataggio in cache', () {
    test(
      'un alimento di Open Food Facts già presente non si duplica',
      () async {
        final s = _Server(
          (r) =>
              _json([_riga('a1', 'Pane integrale', codice: '1000000000001')]),
        );
        final a = await _cache(s).salva(_off());
        expect(a.id, 'a1');
        expect(
          s.richieste.length,
          1,
          reason: 'solo la lettura, nessun inserimento',
        );
        expect(s.richieste.single.method, 'GET');
        expect(
          s.richieste.single.url.queryParameters['codice_barre'],
          'eq.1000000000001',
        );
      },
    );

    test(
      'se non c\'è lo inserisce con la fonte e senza proprietario',
      () async {
        final s = _Server((r) {
          if (r.method == 'GET') return _json([]);
          return _json(_riga('a9', 'Pane integrale', codice: '1000000000001'));
        });
        final a = await _cache(s).salva(_off());
        expect(a.id, 'a9');
        final post = s.richieste.last;
        expect(post.method, 'POST');
        expect(post.url.path, '/rest/v1/alimenti');
        final corpo = jsonDecode(post.body) as Map<String, dynamic>;
        expect(corpo['fonte'], 'open_food_facts');
        expect(corpo['creato_da'], isNull);
        expect(corpo['kcal_100g'], 250);
        expect(corpo['codice_barre'], '1000000000001');
      },
    );

    test(
      'un alimento personalizzato si crea sempre, a nome dell\'utente',
      () async {
        final s = _Server(
          (r) => _json(_riga('p1', 'Torta', fonte: 'personalizzato')),
        );
        final personalizzato = Alimento(
          nome: 'Torta',
          kcal100g: 380,
          proteine100g: 6,
          carboidrati100g: 52,
          grassi100g: 16,
          fonte: FonteAlimento.personalizzato,
        );
        final a = await _cache(s).salva(personalizzato);
        expect(a.id, 'p1');
        expect(s.richieste.length, 1, reason: 'nessuna ricerca di duplicati');
        final corpo =
            jsonDecode(s.richieste.single.body) as Map<String, dynamic>;
        expect(corpo['fonte'], 'personalizzato');
        expect(corpo['creato_da'], 'nut-1');
      },
    );

    test('inserimento in corsa con un altro dispositivo (23505): si riusa quello presente', () async {
      var letture = 0;
      final s = _Server((r) {
        if (r.method == 'GET') {
          letture++;
          return letture == 1
              ? _json([])
              : _json([_riga('a5', 'Pane integrale', codice: '1000000000001')]);
        }
        return _json({
          'code': '23505',
          'message': 'duplicate key value violates unique constraint',
        }, 409);
      });
      final a = await _cache(s).salva(_off());
      expect(a.id, 'a5');
    });
  });

  group('Recenti e preferiti', () {
    test('segnaUso: upsert che aggiorna solo ultimo_uso', () async {
      final s = _Server((r) => http.Response('', 201));
      await _cache(s).segnaUso('a1');
      final r = s.richieste.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/rest/v1/alimenti_nutrizionista');
      expect(
        r.url.queryParameters['on_conflict'],
        'nutrizionista_id,alimento_id',
      );
      expect(r.headers['Prefer'], contains('resolution=merge-duplicates'));
      final corpo = jsonDecode(r.body) as Map<String, dynamic>;
      expect(corpo['nutrizionista_id'], 'nut-1');
      expect(corpo['alimento_id'], 'a1');
      expect(corpo['ultimo_uso'], isNotNull);
      expect(
        corpo.containsKey('preferito'),
        isFalse,
        reason: 'non tocca la stella',
      );
    });

    test('impostaPreferito: upsert che aggiorna solo preferito', () async {
      final s = _Server((r) => http.Response('', 201));
      await _cache(s).impostaPreferito('a1', true);
      final r = s.richieste.single;
      expect(
        r.url.queryParameters['on_conflict'],
        'nutrizionista_id,alimento_id',
      );
      expect(r.headers['Prefer'], contains('resolution=merge-duplicates'));
      final corpo = jsonDecode(r.body) as Map<String, dynamic>;
      expect(corpo['preferito'], true);
      expect(
        corpo.containsKey('ultimo_uso'),
        isFalse,
        reason: 'non tocca l\'uso',
      );
    });

    test(
      'recenti: righe dell\'utente, dalla più recente, con l\'alimento incluso',
      () async {
        final s = _Server(
          (r) => _json([
            {'preferito': true, 'alimenti': _riga('a1', 'Pane')},
            {'preferito': false, 'alimenti': _riga('a2', 'Latte')},
          ]),
        );
        final recenti = await _cache(s).recenti(limite: 2);
        final q = s.richieste.single.url.queryParameters;
        expect(s.richieste.single.url.path, '/rest/v1/alimenti_nutrizionista');
        expect(q['select'], contains('alimenti(*)'));
        expect(q['nutrizionista_id'], 'eq.nut-1');
        expect(q['order'], startsWith('ultimo_uso.desc'));
        expect(q['limit'], '2');
        expect(recenti.map((a) => a.nome), ['Pane', 'Latte']);
        expect(recenti.first.preferito, isTrue);
      },
    );

    test('preferiti: solo quelli con la stella', () async {
      final s = _Server(
        (r) => _json([
          {'preferito': true, 'alimenti': _riga('a1', 'Pane')},
        ]),
      );
      final preferiti = await _cache(s).preferiti();
      expect(s.richieste.single.url.queryParameters['preferito'], 'eq.true');
      expect(preferiti.single.nome, 'Pane');
    });
  });

  group('Errori', () {
    test('senza sessione: errore chiaro e nessuna richiesta', () async {
      final s = _Server((r) => _json([]));
      await expectLater(
        _cache(s, utente: null).segnaUso('a1'),
        throwsA(
          isA<ErroreOperazione>().having((e) => e.codice, 'codice', 'sessione'),
        ),
      );
      expect(s.richieste, isEmpty);
    });

    test(
      'errore del database: messaggio in italiano senza dettagli tecnici',
      () async {
        final s = _Server(
          (r) => _json({'code': '42501', 'message': 'segreto interno'}, 403),
        );
        await expectLater(
          _cache(s).recenti(),
          throwsA(
            isA<ErroreOperazione>().having(
              (e) => e.messaggio,
              'messaggio',
              isNot(contains('segreto interno')),
            ),
          ),
        );
      },
    );
  });
}
