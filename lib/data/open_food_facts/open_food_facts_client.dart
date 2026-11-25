import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/modelli/alimento.dart';
import '../../domain/regole/validazione_alimento.dart';
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
    this.ricercheAlMinuto = 8,
    DateTime Function()? adesso,
  }) : _client = client ?? http.Client(),
       _adesso = adesso ?? DateTime.now;

  /// Recapito del progetto nel `User-Agent` (il nome dell'app).
  final String contatto;

  /// Tempo massimo di una richiesta (RNF_P_3: la ricerca resta sotto 2 s in
  /// condizioni normali; oltre questo limite si usa la cache).
  final Duration timeout;

  final String host;

  /// Ricerche per nome consentite in un minuto. Open Food Facts ne accetta
  /// circa 10 per indirizzo: si resta sotto, e oltre il limite si usa la
  /// cache senza chiamare il servizio.
  final int ricercheAlMinuto;

  final http.Client _client;
  final DateTime Function() _adesso;
  final List<DateTime> _ricercheRecenti = [];

  /// Coda delle richieste: ognuna parte quando la precedente è finita.
  Future<void> _ultima = Future<void>.value();

  String get userAgent => 'Cenato/1.0 ($contatto)';

  static const _campi = 'code,product_name,product_name_it,brands,nutriments';
  static const _lunghezzaMinimaRicerca = 2;

  @override
  Future<List<Alimento>> cercaPerNome(String testo, {int limite = 10}) async {
    final termine = testo.trim();
    if (termine.length < _lunghezzaMinimaRicerca) return const [];
    _rispettaLimite();

    final uri = Uri.https(host, '/cgi/search.pl', {
      'search_terms': termine,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'lc': 'it',
      // Solo prodotti venduti in Italia: nomi in italiano e meno rumore.
      'tagtype_0': 'countries',
      'tag_contains_0': 'contains',
      'tag_0': 'italy',
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
    final candidati = <Alimento>[];
    for (final p in prodotti) {
      if (p is! Map<String, dynamic>) continue;
      final alimento = alimentoDaProdotto(p);
      if (alimento == null) continue;
      final chiave =
          '${alimento.nome.toLowerCase()}|${(alimento.marca ?? '').toLowerCase()}';
      if (!visti.add(chiave)) continue;
      candidati.add(alimento);
    }
    return _perPertinenza(candidati, termine).take(limite).toList();
  }

  void _rispettaLimite() {
    final adesso = _adesso();
    _ricercheRecenti.removeWhere(
      (t) => adesso.difference(t) >= const Duration(minutes: 1),
    );
    if (_ricercheRecenti.length >= ricercheAlMinuto) {
      throw const ServizioAlimentiNonDisponibile('limite di richieste');
    }
    _ricercheRecenti.add(adesso);
  }

  /// Minuscole e senza accenti, per confrontare nomi e testo cercato.
  static String normalizza(String testo) {
    const da = 'àáâäèéêëìíîïòóôöùúûüçñ';
    const a = 'aaaaeeeeiiiioooouuuucn';
    final buffer = StringBuffer();
    for (final c in testo.toLowerCase().split('')) {
      final i = da.indexOf(c);
      buffer.write(i < 0 ? c : a[i]);
    }
    return buffer.toString();
  }

  /// Tiene i prodotti il cui nome (o marca) contiene tutte le parole cercate e
  /// mette per primi quelli che iniziano per la prima parola, poi quelli in
  /// cui una parola inizia così, infine gli altri. La ricerca di Open Food
  /// Facts guarda anche gli ingredienti e restituirebbe, per "pane", le
  /// crocchette "panate": qui si scartano.
  static List<Alimento> _perPertinenza(
    List<Alimento> alimenti,
    String termine,
  ) {
    final parole = normalizza(termine)
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parole.isEmpty) return alimenti;
    final punteggi = <(int, int, Alimento)>[];
    for (var i = 0; i < alimenti.length; i++) {
      final a = alimenti[i];
      final nome = normalizza(a.nome);
      final tutto = '$nome ${normalizza(a.marca ?? '')}';
      if (!parole.every(tutto.contains)) continue;
      final inizio = RegExp('(^|[^a-z0-9])${RegExp.escape(parole.first)}');
      final punteggio = nome.startsWith(parole.first)
          ? 0
          : (inizio.hasMatch(nome) ? 1 : 2);
      punteggi.add((punteggio, i, a));
    }
    // L'indice mantiene l'ordine di Open Food Facts a parità di punteggio.
    punteggi.sort((x, y) {
      final c = x.$1.compareTo(y.$1);
      return c != 0 ? c : x.$2.compareTo(y.$2);
    });
    return [for (final p in punteggi) p.$3];
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

    // Valori fuori scala (errori frequenti nei dati) diventano "mancanti".
    double? valore(String chiave, double massimo) {
      final v = n[chiave];
      final d = switch (v) {
        num x => x.toDouble(),
        String s => double.tryParse(s),
        _ => null,
      };
      if (d == null || d.isNaN || d < 0 || d > massimo) return null;
      return (d * 10).round() / 10;
    }

    double? macro(String chiave) =>
        valore(chiave, ValidazioneAlimento.macroMax);

    // Se le kcal mancano o sono assurde si ricavano dai kJ (1 kcal = 4,184 kJ).
    double? kcal = valore('energy-kcal_100g', ValidazioneAlimento.kcalMax);
    if (kcal == null) {
      final kj = valore('energy_100g', ValidazioneAlimento.kcalMax * 4.184);
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
      proteine100g: macro('proteins_100g'),
      carboidrati100g: macro('carbohydrates_100g'),
      grassi100g: macro('fat_100g'),
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
