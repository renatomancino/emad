import 'package:flutter_test/flutter_test.dart';

import 'package:cenato/data/alimenti_cache.dart';
import 'package:cenato/data/alimenti_repository.dart';
import 'package:cenato/data/finto/alimenti_cache_in_memoria.dart';
import 'package:cenato/data/finto/fonte_alimenti_online_finta.dart';
import 'package:cenato/domain/modelli/alimento.dart';
import 'package:cenato/domain/regole/codice_barre.dart';
import 'package:cenato/domain/repository/alimenti_repository.dart';
import 'package:cenato/domain/repository/pazienti_repository.dart';

/// Codice a barre: normalizzazione, letture ripetute e ricerca con cache
/// (RF_GP_4, UC_GP_3, SD_2).
void main() {
  group('Normalizzazione del codice letto', () {
    test('EAN-13 valido resta com\'è', () {
      expect(CodiceBarre.normalizza('3017620422003'), '3017620422003');
      expect(CodiceBarre.normalizza(' 8076800195057 '), '8076800195057');
    });

    test('cifra di controllo sbagliata: lettura scartata', () {
      expect(CodiceBarre.normalizza('3017620422004'), isNull);
    });

    test('UPC-A (12 cifre) diventa EAN-13 con lo 0 davanti', () {
      expect(CodiceBarre.normalizza('036000291452'), '0036000291452');
    });

    test('EAN-8 valido resta di 8 cifre', () {
      expect(CodiceBarre.normalizza('96385074'), '96385074');
      expect(CodiceBarre.normalizza('96385075'), isNull);
    });

    test('UPC-E si espande nell\'UPC-A equivalente, poi in EAN-13', () {
      expect(CodiceBarre.espandiUpcE('01234565'), '012345000065');
      expect(CodiceBarre.espandiUpcE('04252614'), '042100005264');
      expect(CodiceBarre.normalizza('01234565', upcE: true), '0012345000065');
      // Le stesse 8 cifre sono anche un EAN-8 valido: decide il formato
      // indicato dallo scanner.
      expect(CodiceBarre.normalizza('01234565'), '01234565');
    });

    test('testo, lunghezze sbagliate e vuoto: scartati', () {
      for (final s in [
        '',
        'abc',
        '12345',
        '123456789012345',
        '30176204220a3',
      ]) {
        expect(CodiceBarre.normalizza(s), isNull, reason: s);
      }
    });
  });

  group('Letture ripetute', () {
    test('lo stesso codice entro 3 secondi si ignora, poi si riaccetta', () {
      var adesso = DateTime(2026, 11, 27, 10);
      final filtro = FiltroLetture(adesso: () => adesso);
      expect(filtro.accetta('3017620422003'), isTrue);
      adesso = adesso.add(const Duration(milliseconds: 300));
      expect(filtro.accetta('3017620422003'), isFalse);
      adesso = adesso.add(const Duration(seconds: 3));
      expect(filtro.accetta('3017620422003'), isTrue);
    });

    test('un codice diverso si accetta subito', () {
      final filtro = FiltroLetture();
      expect(filtro.accetta('3017620422003'), isTrue);
      expect(filtro.accetta('8076800195057'), isTrue);
    });
  });

  group('Ricerca per codice a barre (cache, poi Open Food Facts)', () {
    late FonteAlimentiOnlineFinta online;
    late AlimentiCacheInMemoria cache;
    late AlimentiRepositoryImpl repo;

    setUp(() {
      online = FonteAlimentiOnlineFinta();
      cache = AlimentiCacheInMemoria();
      repo = AlimentiRepositoryImpl(cache: cache, online: online);
    });

    test('prodotto noto: trovato online, non ancora in cache', () async {
      final esito = await repo.perCodiceBarre('8000000000095');
      expect(esito, isA<CodiceTrovato>());
      final t = esito as CodiceTrovato;
      expect(t.alimento.nome, 'Yogurt greco');
      expect(t.alimento.kcal100g, 97);
      expect(t.daCache, isFalse);
      expect(await cache.perCodiceBarre('8000000000095'), isNull);
    });

    test('aggiunto al pasto entra in cache con fonte e codice; la seconda '
        'scansione non chiama Open Food Facts', () async {
      final t = await repo.perCodiceBarre('8000000000095') as CodiceTrovato;
      final salvato = await repo.scegli(t.alimento);
      expect(salvato.id, isNotNull);
      expect(salvato.codiceBarre, '8000000000095');
      expect(salvato.fonte, FonteAlimento.openFoodFacts);
      expect(online.chiamateCodice, 1);

      final diNuovo = await repo.perCodiceBarre('8000000000095');
      expect((diNuovo as CodiceTrovato).daCache, isTrue);
      expect(diNuovo.alimento.id, salvato.id);
      expect(online.chiamateCodice, 1);
      // È anche tra i recenti.
      expect((await repo.recenti()).first.id, salvato.id);
    });

    test('dati incompleti: niente cache, si propone l\'inserimento', () async {
      final esito = await repo.perCodiceBarre('8000000000125');
      expect(esito, isA<CodiceIncompleto>());
      expect((esito as CodiceIncompleto).alimento.nome, 'Prodotto senza dati');
    });

    test('codice sconosciuto: non trovato', () async {
      expect(
        await repo.perCodiceBarre('8000000000132'),
        isA<CodiceNonTrovato>(),
      );
    });

    test(
      'Open Food Facts spento: servizio non disponibile, nessun errore',
      () async {
        online.nonDisponibile = true;
        expect(
          await repo.perCodiceBarre('8000000000095'),
          isA<CodiceServizioNonDisponibile>(),
        );
      },
    );

    test(
      'Open Food Facts spento ma codice in cache: si trova lo stesso',
      () async {
        final t = await repo.perCodiceBarre('8000000000095') as CodiceTrovato;
        await repo.scegli(t.alimento);
        online.nonDisponibile = true;
        expect(
          await repo.perCodiceBarre('8000000000095'),
          isA<CodiceTrovato>(),
        );
      },
    );

    test(
      'il codice di Open Food Facts in altra forma si salva come letto',
      () async {
        final repo = AlimentiRepositoryImpl(
          cache: cache,
          online: _OnlineCodiceCorto(),
        );
        final t = await repo.perCodiceBarre('0036000291452') as CodiceTrovato;
        expect(t.alimento.codiceBarre, '0036000291452');
      },
    );

    test('inserito a mano con il codice: la scansione successiva lo trova '
        'tra i propri, senza chiamare Open Food Facts', () async {
      final creato = await repo.creaPersonalizzato(
        nome: 'Yogurt della latteria',
        kcal100g: 80,
        proteine100g: 4,
        carboidrati100g: 6,
        grassi100g: 3.5,
        codiceBarre: '8000000000132',
      );
      expect(creato.codiceBarre, '8000000000132');
      expect(creato.fonte, FonteAlimento.personalizzato);
      final esito = await repo.perCodiceBarre('8000000000132');
      expect((esito as CodiceTrovato).alimento.id, creato.id);
      expect(esito.daCache, isTrue);
      expect(online.chiamateCodice, 0);
    });

    test('personalizzato e Open Food Facts con lo stesso codice: vince il '
        'personalizzato', () async {
      final t = await repo.perCodiceBarre('8000000000095') as CodiceTrovato;
      await repo.scegli(t.alimento);
      final mio = await repo.creaPersonalizzato(
        nome: 'Il mio yogurt',
        kcal100g: 90,
        proteine100g: 8,
        carboidrati100g: 4,
        grassi100g: 4,
        codiceBarre: '8000000000095',
      );
      final esito = await repo.perCodiceBarre('8000000000095');
      expect((esito as CodiceTrovato).alimento.id, mio.id);
    });

    test('lo stesso codice inserito due volte a mano: errore chiaro', () async {
      Future<Alimento> crea() => repo.creaPersonalizzato(
        nome: 'Yogurt',
        kcal100g: 80,
        proteine100g: 4,
        carboidrati100g: 6,
        grassi100g: 3.5,
        codiceBarre: '8000000000132',
      );
      await crea();
      await expectLater(
        crea(),
        throwsA(
          isA<ErroreOperazione>().having(
            (e) => e.codice,
            'codice',
            erroreCodiceBarreEsistente.codice,
          ),
        ),
      );
    });

    test('codice non valido nel personalizzato: rifiutato', () async {
      await expectLater(
        repo.creaPersonalizzato(
          nome: 'Yogurt',
          kcal100g: 80,
          proteine100g: 4,
          carboidrati100g: 6,
          grassi100g: 3.5,
          codiceBarre: '12AB',
        ),
        throwsA(isA<ErroreOperazione>()),
      );
    });
  });
}

/// Open Food Facts che risponde con il codice senza lo 0 davanti.
class _OnlineCodiceCorto implements FonteAlimentiOnline {
  @override
  Future<List<Alimento>> cercaPerNome(String testo, {int limite = 10}) async =>
      const [];

  @override
  Future<Alimento?> perCodiceBarre(String codice) async => const Alimento(
    nome: 'Prodotto USA',
    codiceBarre: '36000291452',
    kcal100g: 100,
    proteine100g: 1,
    carboidrati100g: 20,
    grassi100g: 1,
    fonte: FonteAlimento.openFoodFacts,
  );
}
