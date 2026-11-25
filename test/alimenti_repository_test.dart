import 'package:flutter_test/flutter_test.dart';

import 'package:cenato/data/alimenti_repository.dart';
import 'package:cenato/data/finto/alimenti_cache_in_memoria.dart';
import 'package:cenato/domain/modelli/alimento.dart';
import 'package:cenato/domain/regole/validazione_alimento.dart';
import 'package:cenato/domain/repository/alimenti_repository.dart';
import 'package:cenato/domain/repository/pazienti_repository.dart';

/// Servizio online di prova: risponde con una lista fissa o fallisce.
class _Online implements FonteAlimentiOnline {
  _Online(this.risultati);

  List<Alimento> risultati;
  Duration ritardo = Duration.zero;
  bool nonDisponibile = false;
  int chiamate = 0;

  @override
  Future<List<Alimento>> cercaPerNome(String testo, {int limite = 10}) async {
    chiamate++;
    if (ritardo > Duration.zero) await Future<void>.delayed(ritardo);
    if (nonDisponibile) throw const ServizioAlimentiNonDisponibile('prova');
    return risultati.take(limite).toList();
  }

  @override
  Future<Alimento?> perCodiceBarre(String codice) async => null;
}

Alimento _off(
  String nome, {
  String? codice,
  String? marca,
  double? kcal = 250,
}) => Alimento(
  nome: nome,
  marca: marca,
  codiceBarre: codice,
  kcal100g: kcal,
  proteine100g: 8,
  carboidrati100g: 49,
  grassi100g: 1.5,
  fonte: FonteAlimento.openFoodFacts,
);

void main() {
  late AlimentiCacheInMemoria cache;
  late _Online online;
  late AlimentiRepositoryImpl repo;

  setUp(() {
    cache = AlimentiCacheInMemoria();
    online = _Online([
      _off('Pane integrale', codice: '1000000000001', marca: 'Forno'),
      _off('Pane bianco', codice: '1000000000002'),
      _off('Pane senza dati', codice: '1000000000003', kcal: null),
    ]);
    repo = AlimentiRepositoryImpl(cache: cache, online: online);
  });

  Future<void> riempiCache(int quanti) async {
    for (var i = 0; i < quanti; i++) {
      await repo.creaPersonalizzato(
        nome: 'Pane casalingo $i',
        kcal100g: 250,
        proteine100g: 8,
        carboidrati100g: 49,
        grassi100g: 1.5,
      );
    }
  }

  group('Ricerca: prima la cache, poi online', () {
    test('un testo troppo corto non cerca da nessuna parte', () async {
      final r = await repo.cerca('p');
      expect(r.alimenti, isEmpty);
      expect(online.chiamate, 0);
    });

    test('con la cache vuota si usa il servizio online', () async {
      final r = await repo.cerca('pane');
      expect(r.alimenti.map((a) => a.nome), contains('Pane integrale'));
      expect(online.chiamate, 1);
      expect(r.onlineNonDisponibile, isFalse);
    });

    test('i risultati online non si salvano finché non si sceglie', () async {
      await repo.cerca('pane');
      expect(await cache.cercaPerNome('pane', limite: 20), isEmpty);
    });

    test('una seconda ricerca trova l\'alimento scelto nella cache', () async {
      final trovati = (await repo.cerca('pane')).alimenti;
      final scelto = await repo.scegli(
        trovati.firstWhere((a) => a.nome == 'Pane integrale'),
      );
      expect(scelto.id, isNotNull);
      expect(scelto.fonte, FonteAlimento.openFoodFacts);

      final seconda = (await repo.cerca('pane')).alimenti;
      expect(seconda.first.id, scelto.id, reason: 'prima la cache');
      // Lo stesso prodotto online non compare due volte.
      expect(seconda.where((a) => a.codiceBarre == '1000000000001').length, 1);
    });

    test('con 5 risultati in cache non si chiama il servizio online', () async {
      await riempiCache(5);
      final r = await repo.cerca('pane');
      expect(r.alimenti.length, 5);
      expect(r.onlineSaltato, isTrue);
      expect(online.chiamate, 0);
    });

    test(
      '"anche online" chiama il servizio anche con la cache piena',
      () async {
        await riempiCache(5);
        final r = await repo.cerca('pane', anchePerOnline: true);
        expect(online.chiamate, 1);
        expect(r.alimenti.length, greaterThan(5));
        expect(r.onlineSaltato, isFalse);
      },
    );

    test('servizio non disponibile: si usa la cache e lo si dice', () async {
      await riempiCache(2);
      online.nonDisponibile = true;
      final r = await repo.cerca('pane');
      expect(r.onlineNonDisponibile, isTrue);
      expect(r.alimenti.length, 2);
    });

    test('servizio non disponibile e cache vuota: nessun errore', () async {
      online.nonDisponibile = true;
      final r = await repo.cerca('pane');
      expect(r.alimenti, isEmpty);
      expect(r.onlineNonDisponibile, isTrue);
    });

    test('misura la durata della ricerca', () async {
      online.ritardo = const Duration(milliseconds: 30);
      final r = await repo.cerca('pane');
      expect(r.durata, greaterThanOrEqualTo(const Duration(milliseconds: 30)));
    });

    test('gli alimenti incompleti arrivano nei risultati, segnalati', () async {
      final r = await repo.cerca('pane');
      final senzaDati = r.alimenti.firstWhere(
        (a) => a.nome == 'Pane senza dati',
      );
      expect(senzaDati.completo, isFalse);
    });
  });

  group('Scelta e salvataggio in cache', () {
    test('un alimento incompleto non si salva', () async {
      final r = await repo.cerca('pane');
      final senzaDati = r.alimenti.firstWhere(
        (a) => a.nome == 'Pane senza dati',
      );
      expect(repo.scegli(senzaDati), throwsA(isA<ErroreOperazione>()));
      expect(await cache.cercaPerNome('senza dati', limite: 5), isEmpty);
    });

    test('scegliere due volte lo stesso prodotto non lo duplica', () async {
      final a = _off('Biscotti', codice: '2000000000001');
      final uno = await repo.scegli(a);
      final due = await repo.scegli(a);
      expect(due.id, uno.id);
      expect((await cache.cercaPerNome('biscotti', limite: 10)).length, 1);
    });

    test(
      'lo stesso nome e marca senza codice a barre non si duplica',
      () async {
        final a = _off('Marmellata', marca: 'Nonna');
        final uno = await repo.scegli(a);
        final due = await repo.scegli(a);
        expect(due.id, uno.id);
      },
    );

    test('recenti: dall\'ultimo usato, con limite', () async {
      final a = await repo.scegli(_off('Alfa', codice: '3000000000001'));
      final b = await repo.scegli(_off('Beta', codice: '3000000000002'));
      final c = await repo.scegli(_off('Gamma', codice: '3000000000003'));
      await repo.scegli(a); // usato di nuovo: torna in cima
      final recenti = await repo.recenti(limite: 2);
      expect(recenti.map((x) => x.id), [a.id, c.id]);
      expect(recenti.any((x) => x.id == b.id), isFalse);
    });
  });

  group('Alimento personalizzato (RF_GP_5)', () {
    test('si crea con fonte "personalizzato" e si ritrova', () async {
      final a = await repo.creaPersonalizzato(
        nome: 'Torta della nonna',
        kcal100g: 380,
        proteine100g: 6,
        carboidrati100g: 52,
        grassi100g: 16,
      );
      expect(a.fonte, FonteAlimento.personalizzato);
      expect(a.id, isNotNull);

      final trovati = (await repo.cerca('torta')).alimenti;
      expect(trovati.map((x) => x.id), contains(a.id));
      expect((await repo.recenti()).map((x) => x.id), contains(a.id));
    });

    test('valori non validi: errore e niente salvato', () async {
      Future<void> prova({
        String nome = 'Prova',
        double kcal = 100,
        double p = 5,
        double c = 5,
        double g = 5,
      }) => expectLater(
        repo.creaPersonalizzato(
          nome: nome,
          kcal100g: kcal,
          proteine100g: p,
          carboidrati100g: c,
          grassi100g: g,
        ),
        throwsA(isA<ErroreOperazione>()),
      );
      await prova(nome: '   ');
      await prova(kcal: -1);
      await prova(kcal: 1000);
      await prova(p: 101);
      await prova(p: 50, c: 40, g: 30); // oltre 100 g su 100 g
      await prova(kcal: double.nan);
      expect(await cache.cercaPerNome('prova', limite: 5), isEmpty);
    });
  });

  group('Preferiti (RF_GP_14)', () {
    test('la stella aggiunge e toglie dai preferiti', () async {
      final a = await repo.scegli(_off('Riso', codice: '4000000000001'));
      await repo.impostaPreferito(a, true);
      expect((await repo.preferiti()).map((x) => x.id), [a.id]);
      await repo.impostaPreferito(a, false);
      expect(await repo.preferiti(), isEmpty);
    });

    test(
      'nei risultati i preferiti vengono per primi e sono segnati',
      () async {
        final a = await repo.scegli(_off('Pane A', codice: '4000000000002'));
        await repo.scegli(_off('Pane B', codice: '4000000000003'));
        await repo.impostaPreferito(a, true);
        final r = (await repo.cerca('pane')).alimenti;
        expect(r.first.id, a.id);
        expect(r.first.preferito, isTrue);
      },
    );

    test('la stella su un risultato online lo salva prima in cache', () async {
      final trovati = (await repo.cerca('pane')).alimenti;
      final integrale = trovati.firstWhere((x) => x.nome == 'Pane integrale');
      await repo.impostaPreferito(integrale, true);
      final preferiti = await repo.preferiti();
      expect(preferiti.single.nome, 'Pane integrale');
      expect(preferiti.single.id, isNotNull);
    });

    test('la stella su un alimento incompleto è un errore', () async {
      final trovati = (await repo.cerca('pane')).alimenti;
      final senzaDati = trovati.firstWhere((x) => x.nome == 'Pane senza dati');
      expect(
        repo.impostaPreferito(senzaDati, true),
        throwsA(isA<ErroreOperazione>()),
      );
    });
  });

  group('Validazione dei valori (form e repository)', () {
    test('legge numeri con la virgola italiana', () {
      expect(ValidazioneAlimento.leggiNumero('12,5'), 12.5);
      expect(ValidazioneAlimento.leggiNumero(' 7 '), 7);
      expect(ValidazioneAlimento.leggiNumero('abc'), isNull);
      expect(ValidazioneAlimento.leggiNumero(''), isNull);
    });

    test('messaggi in italiano per i campi del modulo', () {
      expect(ValidazioneAlimento.nome(''), isNotNull);
      expect(ValidazioneAlimento.nome('Pane'), isNull);
      expect(ValidazioneAlimento.kcal(''), contains('kcal'));
      expect(ValidazioneAlimento.kcal('950'), isNotNull);
      expect(ValidazioneAlimento.kcal('250'), isNull);
      expect(ValidazioneAlimento.macro('101', 'Proteine'), isNotNull);
      expect(ValidazioneAlimento.macro('-1', 'Grassi'), isNotNull);
      expect(ValidazioneAlimento.macro('12,5', 'Grassi'), isNull);
    });
  });
}
