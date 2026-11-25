import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:cenato/data/open_food_facts/open_food_facts_client.dart';
import 'package:cenato/domain/modelli/alimento.dart';
import 'package:cenato/domain/repository/alimenti_repository.dart';

String _fixture(String nome) => File('test/fixtures/$nome').readAsStringSync();

http.Response _json(String corpo, [int stato = 200]) => http.Response(
  corpo,
  stato,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

OpenFoodFactsClient _client(
  Future<http.Response> Function(http.Request) risposta, {
  Duration timeout = const Duration(seconds: 5),
}) => OpenFoodFactsClient(client: MockClient(risposta), timeout: timeout);

void main() {
  group('Ricerca per nome: richiesta', () {
    test('usa lingua italiana, prodotti venduti in Italia, pochi campi e User-Agent', () async {
      late http.Request vista;
      final client = _client((r) async {
        vista = r;
        return _json(_fixture('off_ricerca_pane_italia.json'));
      });
      await client.cercaPerNome('pane', limite: 8);

      expect(vista.url.host, 'world.openfoodfacts.org');
      expect(vista.url.path, '/cgi/search.pl');
      final q = vista.url.queryParameters;
      expect(q['search_terms'], 'pane');
      expect(q['json'], '1');
      expect(q['lc'], 'it');
      expect(q['tagtype_0'], 'countries');
      expect(q['tag_contains_0'], 'contains');
      expect(q['tag_0'], 'italy');
      expect(int.parse(q['page_size']!), lessThanOrEqualTo(30));
      expect(q['fields'], contains('nutriments'));
      expect(vista.headers['User-Agent'], 'Cenato/1.0 (Cenato)');
    });

    test('il contatto nel User-Agent si può cambiare', () {
      final client = OpenFoodFactsClient(contatto: 'progetto Cenato');
      expect(client.userAgent, 'Cenato/1.0 (progetto Cenato)');
    });

    test(
      'un testo vuoto o di un solo carattere non fa nessuna richiesta',
      () async {
        var richieste = 0;
        final client = _client((r) async {
          richieste++;
          return _json('{}');
        });
        expect(await client.cercaPerNome('   '), isEmpty);
        expect(await client.cercaPerNome('p'), isEmpty);
        expect(richieste, 0);
      },
    );
  });

  group('Ricerca per nome: risposta vera (pane, prodotti italiani)', () {
    Future<List<Alimento>> cerca(
      String termine, {
      int limite = 20,
      String fixture = 'off_ricerca_pane_italia.json',
      String Function(String corpo)? modifica,
    }) {
      final corpo = _fixture(fixture);
      final client = _client(
        (r) async => _json(modifica == null ? corpo : modifica(corpo)),
      );
      return client.cercaPerNome(termine, limite: limite);
    }

    /// Applica [f] ai prodotti della risposta e la riserializza.
    String Function(String) tocca(void Function(List<dynamic> prodotti) f) =>
        (corpo) {
          final dati = jsonDecode(corpo) as Map<String, dynamic>;
          f(dati['products'] as List<dynamic>);
          return jsonEncode(dati);
        };

    test('valori per 100 g, nome in italiano e marca principale', () async {
      final trovati = await cerca('pane');
      final integrale = trovati.firstWhere(
        (a) => a.codiceBarre == '8001120895424',
      );
      expect(integrale.nome, 'Pane integrale');
      expect(integrale.marca, 'Coop');
      expect(integrale.kcal100g, 256);
      expect(integrale.proteine100g, 9.7);
      expect(integrale.carboidrati100g, 41);
      expect(integrale.grassi100g, 4.3);
      expect(integrale.fonte, FonteAlimento.openFoodFacts);
      expect(integrale.completo, isTrue);
      expect(integrale.id, isNull);
    });

    test('tiene solo i prodotti pertinenti, quelli che iniziano per "pane" per primi', () async {
      final trovati = await cerca('pane');
      expect(trovati.first.nome.toLowerCase(), startsWith('pane'));
      for (final a in trovati) {
        final testo = OpenFoodFactsClient.normalizza(
          '${a.nome} ${a.marca ?? ''}',
        );
        expect(testo, contains('pane'), reason: a.nome);
      }
      // "Wasa delicate crisp", "Piadelle classiche", "1/2 baguette": scartati.
      expect(trovati.any((a) => a.nome.startsWith('Wasa')), isFalse);
      expect(trovati.any((a) => a.nome.startsWith('Piadelle')), isFalse);
      // Un nome in cui "pane" è dentro una parola resta, ma dopo.
      final croq = trovati.indexWhere((a) => a.nome.contains('CROQ'));
      final integrale = trovati.indexWhere((a) => a.nome == 'Pane integrale');
      expect(croq, greaterThan(integrale));
    });

    test('un prodotto senza nome si scarta', () async {
      final trovati = await cerca('pane');
      expect(trovati.any((a) => a.codiceBarre == '8076809542029'), isFalse);
    });

    test('kcal assurde (1289 per 100 g): si usano i kJ', () async {
      final trovati = await cerca('pane');
      final tastino = trovati.firstWhere((a) => a.marca == 'Tastino');
      expect(tastino.kcal100g, closeTo(950 / 4.184, 0.1));
      expect(tastino.completo, isTrue);
    });

    test('un prodotto senza kcal né kJ è segnalato come incompleto', () async {
      final trovati = await cerca(
        'pane',
        modifica: tocca((prodotti) {
          for (final p in prodotti) {
            if (p['code'] == '8001120895424') {
              (p['nutriments'] as Map).removeWhere(
                (k, _) => (k as String).startsWith('energy'),
              );
            }
          }
        }),
      );
      final integrale = trovati.firstWhere((a) => a.nome == 'Pane integrale');
      expect(integrale.kcal100g, isNull);
      expect(integrale.completo, isFalse);
    });

    test('se mancano le kcal ma ci sono i kJ si convertono', () async {
      final trovati = await cerca(
        'pane',
        modifica: tocca((prodotti) {
          for (final p in prodotti) {
            if (p['code'] == '8001120895424') {
              (p['nutriments'] as Map)
                ..remove('energy-kcal_100g')
                ..remove('energy-kcal');
            }
          }
        }),
      );
      final integrale = trovati.firstWhere((a) => a.nome == 'Pane integrale');
      expect(integrale.kcal100g, closeTo(1079 / 4.184, 0.1));
    });

    test('macro oltre 100 g su 100 g non sono validi: incompleto', () async {
      final trovati = await cerca(
        'pane',
        modifica: tocca((prodotti) {
          for (final p in prodotti) {
            if (p['code'] == '8001120895424') {
              (p['nutriments'] as Map)['proteins_100g'] = 450;
            }
          }
        }),
      );
      final integrale = trovati.firstWhere((a) => a.nome == 'Pane integrale');
      expect(integrale.proteine100g, isNull);
      expect(integrale.completo, isFalse);
    });

    test('stesso nome e stessa marca: un solo risultato', () async {
      final trovati = await cerca(
        'pane',
        modifica: tocca((prodotti) {
          final copia = jsonDecode(
            jsonEncode(
              prodotti.firstWhere((p) => p['code'] == '8001120895424'),
            ),
          ) as Map<String, dynamic>;
          copia['code'] = '9999999999999';
          prodotti.add(copia);
        }),
      );
      expect(trovati.where((a) => a.nome == 'Pane integrale').length, 1);
    });

    test('lo stesso nome con marche diverse resta (Pane di segale)', () async {
      final trovati = await cerca('pane');
      expect(trovati.where((a) => a.nome == 'Pane di segale').length, 2);
    });

    test('il numero di risultati rispetta il limite', () async {
      expect((await cerca('pane', limite: 3)).length, 3);
    });

    test('la ricerca ignora maiuscole e accenti', () async {
      final trovati = await cerca('PANÉ');
      expect(trovati, isNotEmpty);
    });
  });

  group('Errori e limiti di richieste', () {
    test('503 (pagina HTML) è "servizio non disponibile"', () {
      final client = _client(
        (r) async =>
            http.Response('<html>Page temporarily unavailable</html>', 503),
      );
      expect(
        client.cercaPerNome('pane'),
        throwsA(isA<ServizioAlimentiNonDisponibile>()),
      );
    });

    test('risposta che non è JSON è "servizio non disponibile"', () {
      final client = _client((r) async => _json('<html>no</html>'));
      expect(
        client.cercaPerNome('pane'),
        throwsA(isA<ServizioAlimentiNonDisponibile>()),
      );
    });

    test('errore di rete è "servizio non disponibile"', () {
      final client = _client((r) async => throw const SocketException('giù'));
      expect(
        client.cercaPerNome('pane'),
        throwsA(isA<ServizioAlimentiNonDisponibile>()),
      );
    });

    test('oltre il timeout è "servizio non disponibile"', () {
      final client = _client(
        (r) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 50),
      );
      expect(
        client.cercaPerNome('pane'),
        throwsA(isA<ServizioAlimentiNonDisponibile>()),
      );
    });

    test('non fa mai più di una richiesta per volta', () async {
      var inVolo = 0;
      var massimo = 0;
      final client = _client((r) async {
        inVolo++;
        if (inVolo > massimo) massimo = inVolo;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        inVolo--;
        return r.url.path.contains('/api/v2/product/')
            ? _json(_fixture('off_prodotto_3017620422003.json'))
            : _json(_fixture('off_ricerca_pane_italia.json'));
      });
      final prima = client.cercaPerNome('pane');
      await Future<void>.delayed(Duration.zero); // la ricerca è in volo
      await Future.wait([
        prima,
        client.perCodiceBarre('3017620422003'),
        client.perCodiceBarre('8076800195057'),
        client.perCodiceBarre('8000500310427'),
      ]);
      expect(massimo, 1);
    });

    test('una richiesta fallita non blocca quelle successive', () async {
      var chiamate = 0;
      final client = _client((r) async {
        chiamate++;
        if (chiamate == 1) return http.Response('x', 503);
        return _json(_fixture('off_ricerca_pane_italia.json'));
      });
      await expectLater(
        client.cercaPerNome('pane'),
        throwsA(isA<ServizioAlimentiNonDisponibile>()),
      );
      expect(await client.cercaPerNome('pane'), isNotEmpty);
    });
  });

  group('Ricerche superate', () {
    test('quelle in coda scavalcate da una più nuova non partono', () async {
      final blocco = Completer<void>();
      final richieste = <String>[];
      final client = _client((r) async {
        richieste.add(r.url.queryParameters['search_terms']!);
        if (richieste.length == 1) await blocco.future;
        return _json(_fixture('off_ricerca_pane_italia.json'));
      });

      final a = client.cercaPerNome('pane');
      await Future<void>.delayed(Duration.zero); // "pane" è in volo
      final b = client.cercaPerNome('pane cereali');
      final c = client.cercaPerNome('pane di segale');
      final esitoB = expectLater(
        b,
        throwsA(isA<ServizioAlimentiNonDisponibile>()),
      );
      blocco.complete();

      await a;
      await esitoB;
      expect(await c, isNotEmpty);
      expect(richieste, [
        'pane',
        'pane di segale',
      ], reason: '"pane cereali" mai spedita');
    });

    test('una ricerca superata non consuma il limite al minuto', () async {
      final blocco = Completer<void>();
      var richieste = 0;
      final client = OpenFoodFactsClient(
        client: MockClient((r) async {
          richieste++;
          if (richieste == 1) await blocco.future;
          return _json(_fixture('off_ricerca_pane_italia.json'));
        }),
        ricercheAlMinuto: 2,
      );
      final a = client.cercaPerNome('pane');
      await Future<void>.delayed(Duration.zero);
      final b = client.cercaPerNome('pane cereali');
      final c = client.cercaPerNome('pane di segale');
      final esitoB = expectLater(
        b,
        throwsA(isA<ServizioAlimentiNonDisponibile>()),
      );
      blocco.complete();
      await a;
      await esitoB;
      // Con un limite di 2: "pane" e "pane di segale" bastano, l'altra non ha pesato.
      expect(await c, isNotEmpty);
      expect(richieste, 2);
    });
  });

  group('Limite di richieste (Open Food Facts: ~10 ricerche al minuto)', () {
    test('dopo 8 ricerche in un minuto non chiama più il servizio', () async {
      var ora = DateTime(2026, 11, 25, 10);
      var richieste = 0;
      final client = OpenFoodFactsClient(
        client: MockClient((r) async {
          richieste++;
          return _json(_fixture('off_ricerca_pane_italia.json'));
        }),
        adesso: () => ora,
      );
      for (var i = 0; i < 8; i++) {
        await client.cercaPerNome('pane');
        ora = ora.add(const Duration(seconds: 3));
      }
      expect(richieste, 8);
      await expectLater(
        client.cercaPerNome('pane'),
        throwsA(isA<ServizioAlimentiNonDisponibile>()),
      );
      expect(richieste, 8, reason: 'nessuna richiesta oltre il limite');

      // Passato il minuto si riparte.
      ora = ora.add(const Duration(minutes: 1));
      expect(await client.cercaPerNome('pane'), isNotEmpty);
      expect(richieste, 9);
    });

    test('i codici a barre non consumano il limite delle ricerche', () async {
      var ora = DateTime(2026, 11, 25, 10);
      final client = OpenFoodFactsClient(
        client: MockClient(
          (r) async => r.url.path.contains('/api/v2/product/')
              ? _json(_fixture('off_prodotto_3017620422003.json'))
              : _json(_fixture('off_ricerca_pane_italia.json')),
        ),
        adesso: () => ora,
      );
      for (var i = 0; i < 8; i++) {
        await client.cercaPerNome('pane');
      }
      expect(await client.perCodiceBarre('3017620422003'), isNotNull);
    });
  });

  group('Ricerca per codice a barre (riusata dalla scheda barcode)', () {
    test('legge un prodotto vero (Nutella)', () async {
      late http.Request vista;
      final client = _client((r) async {
        vista = r;
        return _json(_fixture('off_prodotto_3017620422003.json'));
      });
      final nutella = await client.perCodiceBarre('3017620422003');
      expect(vista.url.path, '/api/v2/product/3017620422003');
      expect(vista.headers['User-Agent'], 'Cenato/1.0 (Cenato)');
      expect(nutella!.nome, 'Nutella');
      expect(nutella.marca, 'Ferrero');
      expect(nutella.kcal100g, 539);
      expect(nutella.proteine100g, 6.3);
      expect(nutella.carboidrati100g, 57.5);
      expect(nutella.grassi100g, 30.9);
      expect(nutella.codiceBarre, '3017620422003');
    });

    test('prodotto non trovato: null', () async {
      final client = _client(
        (r) async => _json(
          '{"code":"123","status":0,"status_verbose":"product not found"}',
          404,
        ),
      );
      expect(await client.perCodiceBarre('1234567890123'), isNull);
    });

    test('un codice non numerico non fa nessuna richiesta', () async {
      var richieste = 0;
      final client = _client((r) async {
        richieste++;
        return _json('{}');
      });
      expect(await client.perCodiceBarre('abc'), isNull);
      expect(richieste, 0);
    });
  });
}
