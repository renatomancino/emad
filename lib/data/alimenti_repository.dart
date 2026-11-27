import '../domain/modelli/alimento.dart';
import '../domain/regole/codice_barre.dart';
import '../domain/regole/validazione_alimento.dart';
import '../domain/repository/alimenti_repository.dart';
import '../domain/repository/pazienti_repository.dart';
import 'alimenti_cache.dart';

/// [AlimentiRepository]: cerca prima nella cache e poi online, salva in cache
/// solo gli alimenti scelti e solo se completi (UC_GP_3, RNF_IN_1, RNF_P_3).
class AlimentiRepositoryImpl implements AlimentiRepository {
  AlimentiRepositoryImpl({
    required this.cache,
    required this.online,
    this.sogliaCache = 5,
  });

  final AlimentiCache cache;
  final FonteAlimentiOnline online;

  /// Con almeno questi risultati in cache non si chiama il servizio online:
  /// meno richieste a Open Food Facts e risposta immediata.
  final int sogliaCache;

  static const _lunghezzaMinimaRicerca = 2;

  /// Chiave per riconoscere lo stesso alimento in cache e online.
  static String _chiave(Alimento a) =>
      a.codiceBarre ??
      '${a.nome.toLowerCase()}|${(a.marca ?? '').toLowerCase()}';

  @override
  Future<RisultatoRicerca> cerca(
    String testo, {
    bool anchePerOnline = false,
    void Function(RisultatoRicerca dallaCache)? alRisultatoDallaCache,
  }) async {
    final termine = testo.trim();
    if (termine.length < _lunghezzaMinimaRicerca) {
      return const RisultatoRicerca(alimenti: []);
    }
    final orologio = Stopwatch()..start();
    final inCache = await cache.cercaPerNome(termine);

    if (!anchePerOnline && inCache.length >= sogliaCache) {
      return RisultatoRicerca(
        alimenti: inCache,
        onlineSaltato: true,
        durata: orologio.elapsed,
      );
    }

    // La cache è già pronta: si mostra subito, senza aspettare il servizio.
    if (inCache.isNotEmpty) {
      alRisultatoDallaCache?.call(
        RisultatoRicerca(alimenti: inCache, durata: orologio.elapsed),
      );
    }

    try {
      final trovatiOnline = await online.cercaPerNome(termine);
      final visti = {for (final a in inCache) _chiave(a)};
      return RisultatoRicerca(
        alimenti: [
          ...inCache,
          for (final a in trovatiOnline)
            if (visti.add(_chiave(a))) a,
        ],
        durata: orologio.elapsed,
      );
    } on ServizioAlimentiNonDisponibile {
      return RisultatoRicerca(
        alimenti: inCache,
        onlineNonDisponibile: true,
        durata: orologio.elapsed,
      );
    }
  }

  @override
  Future<Alimento> scegli(Alimento alimento) async {
    if (alimento.id != null) {
      await cache.segnaUso(alimento.id!);
      return alimento;
    }
    final salvato = await _salvaSeCompleto(alimento);
    await cache.segnaUso(salvato.id!);
    return salvato;
  }

  @override
  Future<EsitoCodiceBarre> perCodiceBarre(String codice) async {
    final inCache = await cache.perCodiceBarre(codice);
    if (inCache != null) return CodiceTrovato(codice, inCache, daCache: true);
    try {
      final online = await this.online.perCodiceBarre(codice);
      if (online == null) return CodiceNonTrovato(codice);
      // Open Food Facts può restituire il codice in un'altra forma (senza lo
      // 0 davanti): si tiene quello letto, così la prossima scansione dello
      // stesso prodotto lo trova in cache.
      final alimento = online.copyWith(codiceBarre: codice);
      return alimento.completo
          ? CodiceTrovato(codice, alimento, daCache: false)
          : CodiceIncompleto(codice, alimento);
    } on ServizioAlimentiNonDisponibile {
      return CodiceServizioNonDisponibile(codice);
    }
  }

  Future<Alimento> _salvaSeCompleto(Alimento alimento) {
    if (!alimento.completo) {
      throw const ErroreOperazione(
        'Mancano dei valori nutrizionali: completa l\'alimento a mano.',
        codice: 'alimento_incompleto',
      );
    }
    return cache.salva(alimento);
  }

  @override
  Future<Alimento> creaPersonalizzato({
    required String nome,
    required double kcal100g,
    required double proteine100g,
    required double carboidrati100g,
    required double grassi100g,
    String? marca,
    String? codiceBarre,
  }) async {
    if (codiceBarre != null && !CodiceBarre.formatoDb.hasMatch(codiceBarre)) {
      throw const ErroreOperazione(
        'Il codice a barre non è valido.',
        codice: 'alimento_non_valido',
      );
    }
    final errore = ValidazioneAlimento.alimento(
      nome: nome,
      kcal100g: kcal100g,
      proteine100g: proteine100g,
      carboidrati100g: carboidrati100g,
      grassi100g: grassi100g,
    );
    if (errore != null) {
      throw ErroreOperazione(errore, codice: 'alimento_non_valido');
    }
    final marcaPulita = marca?.trim();
    final salvato = await cache.salva(
      Alimento(
        nome: nome.trim(),
        marca: marcaPulita == null || marcaPulita.isEmpty ? null : marcaPulita,
        codiceBarre: codiceBarre,
        kcal100g: kcal100g,
        proteine100g: proteine100g,
        carboidrati100g: carboidrati100g,
        grassi100g: grassi100g,
        fonte: FonteAlimento.personalizzato,
      ),
    );
    await cache.segnaUso(salvato.id!);
    return salvato;
  }

  @override
  Future<List<Alimento>> recenti({int limite = 10}) =>
      cache.recenti(limite: limite);

  @override
  Future<List<Alimento>> preferiti() => cache.preferiti();

  @override
  Future<void> impostaPreferito(Alimento alimento, bool preferito) async {
    final salvato = alimento.id == null
        ? await _salvaSeCompleto(alimento)
        : alimento;
    await cache.impostaPreferito(salvato.id!, preferito);
    // Toccare la stella è un uso dell'alimento: compare tra i recenti.
    await cache.segnaUso(salvato.id!);
  }
}
