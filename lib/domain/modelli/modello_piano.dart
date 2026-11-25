import 'alimento.dart';
import 'piano_alimentare.dart';

/// Che cosa contiene un modello (enum `tipo_modello`, RF_GP_9).
enum TipoModello {
  pasto('pasto', 'Pasti salvati'),
  piano('piano', 'Piani modello');

  const TipoModello(this.valoreDb, this.etichetta);

  final String valoreDb;
  final String etichetta;

  static TipoModello daDb(String? valore) =>
      values.firstWhere((t) => t.valoreDb == valore, orElse: () => pasto);
}

/// Pasto salvato o piano modello del nutrizionista (RF_GP_9). È una **copia**:
/// non è legato a un paziente e non cambia se il piano da cui nasce cambia;
/// usarlo in un piano ne inserisce un'altra copia.
///
/// Il [contenuto] è la struttura del pasto o del piano in JSON, con gli
/// alimenti salvati per intero (nome e valori per 100 g), così il modello si
/// apre anche senza interrogare la cache degli alimenti.
class ModelloPiano {
  const ModelloPiano({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.contenuto,
    this.creatoIl,
  });

  final String id;
  final String nome;
  final TipoModello tipo;
  final Map<String, dynamic> contenuto;
  final DateTime? creatoIl;

  /// Il pasto del modello (tipo [TipoModello.pasto]), con chiavi nuove.
  /// Lancia [FormatException] se il contenuto non è leggibile.
  PastoPiano get pasto => pastoDaContenuto(contenuto);

  /// Il piano del modello (tipo [TipoModello.piano]) con la data di inizio
  /// indicata. Lancia [FormatException] se il contenuto non è leggibile.
  PianoAlimentare piano(DateTime dataInizio) =>
      pianoDaContenuto(contenuto, dataInizio);

  /// Riga per gli elenchi: "Colazione · 2 alimenti", "5 giorni · 20 pasti".
  String get descrizione {
    try {
      if (tipo == TipoModello.pasto) {
        final p = pasto;
        return '${p.tipo.etichetta} · ${_alimenti(p.voci.length)}';
      }
      final g = piano(DateTime(2000)).giorni;
      final pasti = g.fold<int>(0, (n, x) => n + x.pasti.length);
      return '${g.length} ${g.length == 1 ? 'giorno' : 'giorni'} · '
          '$pasti ${pasti == 1 ? 'pasto' : 'pasti'}';
    } on FormatException {
      return 'Contenuto non leggibile';
    }
  }

  static String _alimenti(int n) => n == 1 ? '1 alimento' : '$n alimenti';
}

// ----------------------------------------------------------------- codifica

Map<String, dynamic> _daAlimento(Alimento a) => {
  'id': a.id,
  'nome': a.nome,
  'marca': a.marca,
  'codice_barre': a.codiceBarre,
  'kcal_100g': a.kcal100g,
  'proteine_100g': a.proteine100g,
  'carboidrati_100g': a.carboidrati100g,
  'grassi_100g': a.grassi100g,
  'fonte': a.fonte.valoreDb,
};

Alimento _alimento(Object? v) {
  if (v is! Map) throw const FormatException('Alimento mancante');
  final riga = Map<String, dynamic>.from(v);
  if (riga['nome'] is! String || riga['fonte'] is! String) {
    throw const FormatException('Alimento non valido');
  }
  return Alimento.daRiga(riga);
}

double _quantita(Object? v) {
  if (v is num && v > 0) return v.toDouble();
  throw const FormatException('Quantità non valida');
}

/// Contenuto JSON di un pasto: tipo, orario e voci con le loro alternative.
Map<String, dynamic> contenutoDaPasto(PastoPiano p) => {
  'tipo': p.tipo.valoreDb,
  'orario': p.orario,
  'voci': [
    for (final v in p.voci)
      {
        'alimento': _daAlimento(v.alimento),
        'quantita_g': v.quantitaG,
        if (v.alternative.isNotEmpty)
          'alternative': [
            for (final a in v.alternative)
              {'alimento': _daAlimento(a.alimento), 'quantita_g': a.quantitaG},
          ],
      },
  ],
};

/// Contenuto JSON di un piano: giorni → pasti.
Map<String, dynamic> contenutoDaPiano(PianoAlimentare p) => {
  'giorni': [
    for (final g in p.giorni)
      {
        'giorno': g.giornoSettimana,
        'pasti': [for (final x in g.pasti) contenutoDaPasto(x)],
      },
  ],
};

/// Ricostruisce un pasto (con chiavi nuove) da [contenutoDaPasto].
PastoPiano pastoDaContenuto(Map<String, dynamic> c) {
  final tipo = c['tipo'];
  final voci = c['voci'];
  if (tipo is! String || voci is! List) {
    throw const FormatException('Pasto non valido');
  }
  return PastoPiano(
    tipo: TipoPasto.daDb(tipo),
    orario: c['orario'] is String ? c['orario'] as String : null,
    voci: [
      for (final v in voci)
        if (v is Map)
          VocePiano(
            alimento: _alimento(v['alimento']),
            quantitaG: _quantita(v['quantita_g']),
            alternative: [
              for (final a in (v['alternative'] as List? ?? const []))
                if (a is Map)
                  AlternativaPiano(
                    alimento: _alimento(a['alimento']),
                    quantitaG: _quantita(a['quantita_g']),
                  ),
            ],
          )
        else
          throw const FormatException('Voce non valida'),
    ],
  );
}

/// Ricostruisce un piano da [contenutoDaPiano].
PianoAlimentare pianoDaContenuto(Map<String, dynamic> c, DateTime dataInizio) {
  final giorni = c['giorni'];
  if (giorni is! List) throw const FormatException('Piano non valido');
  return PianoAlimentare(
    dataInizio: dataInizio,
    giorni: [
      for (final g in giorni)
        if (g is Map && g['giorno'] is int && g['pasti'] is List)
          GiornoPiano(
            giornoSettimana: g['giorno'] as int,
            pasti: [
              for (final p in g['pasti'] as List)
                if (p is Map)
                  pastoDaContenuto(Map<String, dynamic>.from(p))
                else
                  throw const FormatException('Pasto non valido'),
            ],
          )
        else
          throw const FormatException('Giorno non valido'),
    ]..sort((a, b) => a.giornoSettimana.compareTo(b.giornoSettimana)),
  );
}
