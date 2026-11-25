import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/modelli/alimento.dart';
import '../../domain/repository/alimenti_repository.dart';

/// Client dell'API di Open Food Facts (RNF_IN_1, licenza ODbL).
///
/// Rispetta i limiti di richieste: **una richiesta per volta** (le altre
/// aspettano il loro turno), timeout, pagina piccola, solo i campi
/// necessari e un `User-Agent` che identifica Cenato. La ricerca per nome è
/// meno affidabile del codice a barre: ogni errore diventa
/// [ServizioAlimentiNonDisponibile] e chi chiama ripiega sulla cache.
class OpenFoodFactsClient implements FonteAlimentiOnline {
  OpenFoodFactsClient({
    http.Client? client,
    this.contatto = 'Cenato',
    this.timeout = const Duration(seconds: 5),
    this.host = 'world.openfoodfacts.org',
  }) : _client = client ?? http.Client();

  /// Recapito del progetto nel `User-Agent` (il nome dell'app).
  final String contatto;

  /// Tempo massimo di una richiesta (RNF_P_3: la ricerca resta sotto 2 s in
  /// condizioni normali; oltre questo limite si usa la cache).
  final Duration timeout;

  final String host;
  final http.Client _client;

  /// Coda delle richieste: ognuna parte quando la precedente è finita.
  Future<void> _ultima = Future<void>.value();

  String get userAgent => 'Cenato/1.0 ($contatto)';

  static const _campi = 'code,product_name,product_name_it,brands,nutriments';
  static const _lunghezzaMinimaRicerca = 2;

  @override
  Future<List<Alimento>> cercaPerNome(String testo, {int limite = 10}) async {
    final termine = testo.trim();
    if (termine.length < _lunghezzaMinimaRicerca) return const [];

    final uri = Uri.https(host, '/cgi/search.pl', {
      'search_terms': termine,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'lc': 'it',
      'sort_by': 'unique_scans_n',
      // Qualche risultato in più: alcuni verranno scartati o fusi.
      'page_size': (limite * 2).clamp(10, 30).toString(),
      'fields': _campi,
    });
    final risposta = await _richiedi(uri);
    final dati = _decodifica(risposta);
    final prodotti = dati['products'];
    if (prodotti is! List) {
      throw const ServizioAlimentiNonDisponibile('risposta inattesa');
    }

    final visti = <String>{};
    final risultati = <Alimento>[];
    for (final p in prodotti) {
      if (p is! Map<String, dynamic>) continue;
      final alimento = alimentoDaProdotto(p);
      if (alimento == null) continue;
      final chiave =
          '${alimento.nome.toLowerCase()}|${(alimento.marca ?? '').toLowerCase()}';
      if (!visti.add(chiave)) continue;
      risultati.add(alimento);
      if (risultati.length == limite) break;
    }
    return risultati;
  }

  @override
  Future<Alimento?> perCodiceBarre(String codice) async {
    if (!RegExp(r'^[0-9]{6,14}$').hasMatch(codice)) return null;
    final uri = Uri.https(host, '/api/v2/product/$codice', {'fields': _campi});
    final risposta = await _richiedi(uri, ammettiNonTrovato: true);
    if (risposta.statusCode == 404) return null;
    final dati = _decodifica(risposta);
    final prodotto = dati['product'];
    if (dati['status'] == 0 || prodotto is! Map<String, dynamic>) return null;
    return alimentoDaProdotto(prodotto);
  }

  /// Trasforma un prodotto di Open Food Facts in [Alimento]; `null` se non ha
  /// un nome. I valori mancanti restano `null` (alimento incompleto).
  static Alimento? alimentoDaProdotto(Map<String, dynamic> prodotto) {
    String? testo(Object? v) {
      final s = v is String ? v.trim() : '';
      return s.isEmpty ? null : s;
    }

    final nome =
        testo(prodotto['product_name_it']) ?? testo(prodotto['product_name']);
    if (nome == null) return null;

    final marca = testo((testo(prodotto['brands']) ?? '').split(',').first);
    final codice = testo(prodotto['code']);
    final nutrienti = prodotto['nutriments'];
    final n = nutrienti is Map<String, dynamic> ? nutrienti : const {};

    double? valore(String chiave) {
      final v = n[chiave];
      final d = switch (v) {
        num x => x.toDouble(),
        String s => double.tryParse(s),
        _ => null,
      };
      if (d == null || d < 0 || d.isNaN) return null;
      return (d * 10).round() / 10;
    }

    double? kcal = valore('energy-kcal_100g');
    if (kcal == null) {
      final kj = valore('energy_100g');
      if (kj != null) kcal = (kj / 4.184 * 10).round() / 10;
    }

    return Alimento(
      nome: nome.length > 200 ? nome.substring(0, 200) : nome,
      marca: marca == null
          ? null
          : (marca.length > 120 ? marca.substring(0, 120) : marca),
      codiceBarre: codice != null && RegExp(r'^[0-9]{6,14}$').hasMatch(codice)
          ? codice
          : null,
      kcal100g: kcal,
      proteine100g: valore('proteins_100g'),
      carboidrati100g: valore('carbohydrates_100g'),
      grassi100g: valore('fat_100g'),
      fonte: FonteAlimento.openFoodFacts,
    );
  }

  Map<String, dynamic> _decodifica(http.Response risposta) {
    try {
      final dati = jsonDecode(utf8.decode(risposta.bodyBytes));
      if (dati is Map<String, dynamic>) return dati;
    } on FormatException {
      // Pagina HTML o testo: trattata come servizio non disponibile.
    }
    throw const ServizioAlimentiNonDisponibile('risposta non valida');
  }

  /// Esegue la richiesta GET dopo le precedenti (una per volta).
  Future<http.Response> _richiedi(Uri uri, {bool ammettiNonTrovato = false}) {
    final precedente = _ultima;
    final fine = Completer<void>();
    _ultima = fine.future;
    return precedente.then((_) async {
      try {
        final risposta = await _client
            .get(
              uri,
              headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
            )
            .timeout(timeout);
        if (risposta.statusCode == 200 ||
            (ammettiNonTrovato && risposta.statusCode == 404)) {
          return risposta;
        }
        throw ServizioAlimentiNonDisponibile('HTTP ${risposta.statusCode}');
      } on ServizioAlimentiNonDisponibile {
        rethrow;
      } on TimeoutException {
        throw const ServizioAlimentiNonDisponibile('tempo scaduto');
      } on Exception catch (e) {
        // Rete assente, DNS, TLS: solo il tipo, mai il contenuto.
        throw ServizioAlimentiNonDisponibile(e.runtimeType.toString());
      } finally {
        fine.complete();
      }
    });
  }
}
