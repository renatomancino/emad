import 'dart:async';
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
    test(
      'usa lingua italiana, pochi campi, pagina piccola e User-Agent',
      () async {
        late http.Request vista;
        final client = _client((r) async {
          vista = r;
          return _json(_fixture('off_ricerca_pane.json'));
        });
        await client.cercaPerNome('pane', limite: 8);

        expect(vista.url.host, 'world.openfoodfacts.org');
        expect(vista.url.path, '/cgi/search.pl');
        final q = vista.url.queryParameters;
        expect(q['search_terms'], 'pane');
        expect(q['json'], '1');
        expect(q['lc'], 'it');
        expect(q['page_size'], isNotNull);
        expect(int.parse(q['page_size']!), lessThanOrEqualTo(30));
        expect(q['fields'], contains('nutriments'));
        expect(vista.headers['User-Agent'], 'Cenato/1.0 (Cenato)');
      },
    );

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

  group('Ricerca per nome: risposta', () {
    late List<Alimento> trovati;

    setUp(() async {
      final client = _client(
        (r) async => _json(_fixture('off_ricerca_pane.json')),
      );
      trovati = await client.cercaPerNome('pane', limite: 20);
    });

    test('valori per 100 g, nome in italiano e marca principale', () {
      final spaghetti = trovati.firstWhere(
        (a) => a.codiceBarre == '8076800195057',
      );
      expect(spaghetti.nome, 'Spaghetti n.5');
      expect(spaghetti.marca, 'Barilla');
      expect(spaghetti.kcal100g, 359);
      expect(spaghetti.proteine100g, 13);
      expect(spaghetti.carboidrati100g, 71);
      expect(spaghetti.grassi100g, 2);
      expect(spaghetti.fonte, FonteAlimento.openFoodFacts);
      expect(spaghetti.completo, isTrue);
      expect(spaghetti.id, isNull);
    });

    test('un prodotto senza kcal è segnalato come incompleto', () {
      final senzaDati = trovati.firstWhere((a) => a.nome == 'Pasta senza dati');
      expect(senzaDati.kcal100g, isNull);
      expect(senzaDati.completo, isFalse);
    });

    test('se mancano le kcal ma ci sono i kJ si convertono', () {
      final soloKj = trovati.firstWhere((a) => a.nome == 'Pasta solo kJ');
      expect(soloKj.kcal100g, closeTo(1500 / 4.184, 0.1));
      expect(soloKj.completo, isTrue);
    });

    test('i prodotti senza nome si scartano e i duplicati si fondono', () {
      expect(trovati.any((a) => a.codiceBarre == '9999999999993'), isFalse);
      final spaghetti = trovati.where((a) => a.nome == 'Spaghetti n.5');
      expect(spaghetti.length, 1);
    });

    test('il numero di risultati rispetta il limite', () async {
      final client = _client(
        (r) async => _json(_fixture('off_ricerca_pane.json')),
      );
      final pochi = await client.cercaPerNome('pane', limite: 2);
      expect(pochi.length, 2);
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
        return _json(_fixture('off_ricerca_pane.json'));
      });
      await Future.wait([
        client.cercaPerNome('pane'),
        client.cercaPerNome('latte'),
        client.cercaPerNome('riso'),
      ]);
      expect(massimo, 1);
    });

    test('una richiesta fallita non blocca quelle successive', () async {
      var chiamate = 0;
      final client = _client((r) async {
        chiamate++;
        if (chiamate == 1) return http.Response('x', 503);
        return _json(_fixture('off_ricerca_pane.json'));
      });
      await expectLater(
        client.cercaPerNome('pane'),
        throwsA(isA<ServizioAlimentiNonDisponibile>()),
      );
      expect(await client.cercaPerNome('pane'), isNotEmpty);
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
