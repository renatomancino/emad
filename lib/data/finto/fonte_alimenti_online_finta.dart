import '../../domain/modelli/alimento.dart';
import '../../domain/repository/alimenti_repository.dart';

/// Servizio online di alimenti finto, per test e demo senza rete
/// (`CENATO_RUOLO_FINTO`). Alimenti **fittizi** con valori indicativi:
/// non sono dati di Open Food Facts.
class FonteAlimentiOnlineFinta implements FonteAlimentiOnline {
  FonteAlimentiOnlineFinta({this.nonDisponibile = false});

  /// Se vero, ogni ricerca fallisce come con Open Food Facts spento.
  bool nonDisponibile;

  /// Attesa prima di rispondere (per provare lo stato di caricamento).
  Duration ritardo = Duration.zero;

  /// Quante ricerche online sono state fatte.
  int chiamate = 0;

  static Alimento _o(
    String nome,
    String codice,
    double? kcal,
    double p,
    double c,
    double g, {
    String? marca,
  }) => Alimento(
    nome: nome,
    marca: marca,
    codiceBarre: codice,
    kcal100g: kcal,
    proteine100g: p,
    carboidrati100g: c,
    grassi100g: g,
    fonte: FonteAlimento.openFoodFacts,
  );

  static final List<Alimento> _catalogo = [
    _o(
      'Pane integrale',
      '8000000000011',
      247,
      9,
      41.2,
      3.4,
      marca: 'Forno Demo',
    ),
    _o('Pane bianco', '8000000000028', 265, 8.5, 52, 1.8),
    _o(
      'Pasta di semola',
      '8000000000035',
      359,
      13,
      71,
      2,
      marca: 'Pastificio Demo',
    ),
    _o('Riso bianco', '8000000000042', 354, 7.1, 79.5, 0.6),
    _o('Latte parzialmente scremato', '8000000000059', 46, 3.3, 4.9, 1.6),
    _o('Mela', '8000000000066', 52, 0.3, 13.8, 0.2),
    _o('Uova', '8000000000073', 143, 12.6, 0.7, 9.5),
    _o('Olio extravergine di oliva', '8000000000080', 884, 0, 0, 100),
    _o('Yogurt greco', '8000000000097', 97, 9, 3.9, 5),
    _o('Petto di pollo', '8000000000103', 110, 23, 0, 1.2),
    _o('Biscotti secchi', '8000000000110', 432, 7, 76, 10, marca: 'Dolci Demo'),
    _o('Prodotto senza dati', '8000000000127', null, 5, 10, 2),
  ];

  @override
  Future<List<Alimento>> cercaPerNome(String testo, {int limite = 10}) async {
    chiamate++;
    if (ritardo > Duration.zero) await Future<void>.delayed(ritardo);
    if (nonDisponibile) {
      throw const ServizioAlimentiNonDisponibile('servizio finto spento');
    }
    final t = testo.trim().toLowerCase();
    return _catalogo
        .where((a) => a.nome.toLowerCase().contains(t))
        .take(limite)
        .toList();
  }

  @override
  Future<Alimento?> perCodiceBarre(String codice) async {
    for (final a in _catalogo) {
      if (a.codiceBarre == codice) return a;
    }
    return null;
  }
}
