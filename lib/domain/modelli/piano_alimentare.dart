import 'alimento.dart';

/// Tipi di pasto previsti (enum `tipo_pasto`, RF_GP_1).
enum TipoPasto {
  colazione('colazione', 'Colazione', '08:00'),
  spuntino('spuntino', 'Spuntino', '10:30'),
  pranzo('pranzo', 'Pranzo', '13:00'),
  merenda('merenda', 'Merenda', '16:30'),
  cena('cena', 'Cena', '20:00');

  const TipoPasto(this.valoreDb, this.etichetta, this.orarioPredefinito);

  final String valoreDb;
  final String etichetta;

  /// Orario proposto per un pasto nuovo, modificabile ("HH:mm").
  final String orarioPredefinito;

  static TipoPasto daDb(String? valore) => values.firstWhere(
    (t) => t.valoreDb == valore,
    orElse: () => TipoPasto.spuntino,
  );
}

/// Stati di una versione del piano (enum `stato_piano`, RF_GP_7).
enum StatoPiano {
  bozza('bozza', 'Bozza'),
  corrente('corrente', 'In uso'),
  superato('superato', 'Superata');

  const StatoPiano(this.valoreDb, this.etichetta);

  final String valoreDb;
  final String etichetta;

  static StatoPiano daDb(String? valore) => values.firstWhere(
    (s) => s.valoreDb == valore,
    orElse: () => StatoPiano.bozza,
  );
}

/// Giorni della settimana come nel database: 1 = lunedì … 7 = domenica.
abstract final class GiorniSettimana {
  static const tutti = [1, 2, 3, 4, 5, 6, 7];
  static const nomi = [
    'Lunedì',
    'Martedì',
    'Mercoledì',
    'Giovedì',
    'Venerdì',
    'Sabato',
    'Domenica',
  ];
  static const abbreviati = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  static String nome(int giorno) => nomi[giorno - 1];
  static String abbreviato(int giorno) => abbreviati[giorno - 1];
}

/// Calorie e macronutrienti, in grammi (voce, pasto, giorno o obiettivo).
class Macro {
  const Macro({
    this.kcal = 0,
    this.proteineG = 0,
    this.carboidratiG = 0,
    this.grassiG = 0,
  });

  static const zero = Macro();

  final double kcal;
  final double proteineG;
  final double carboidratiG;
  final double grassiG;

  Macro operator +(Macro altro) => Macro(
    kcal: kcal + altro.kcal,
    proteineG: proteineG + altro.proteineG,
    carboidratiG: carboidratiG + altro.carboidratiG,
    grassiG: grassiG + altro.grassiG,
  );

  Macro operator -(Macro altro) => Macro(
    kcal: kcal - altro.kcal,
    proteineG: proteineG - altro.proteineG,
    carboidratiG: carboidratiG - altro.carboidratiG,
    grassiG: grassiG - altro.grassiG,
  );

  @override
  bool operator ==(Object other) =>
      other is Macro &&
      other.kcal == kcal &&
      other.proteineG == proteineG &&
      other.carboidratiG == carboidratiG &&
      other.grassiG == grassiG;

  @override
  int get hashCode => Object.hash(kcal, proteineG, carboidratiG, grassiG);

  @override
  String toString() =>
      'Macro($kcal kcal, P $proteineG, C $carboidratiG, G $grassiG)';
}

int _contatore = 0;

/// Chiave locale (solo per l'interfaccia: liste riordinabili, voci nuove non
/// ancora salvate). Non coincide con l'id del database.
String nuovaChiave() => 'k${++_contatore}';

/// Alternativa ammessa per una voce (RF_GP_6): alimento e quantità. Sono le
/// uniche scelte che il paziente ha nel check-in "Alternativa".
class AlternativaPiano {
  const AlternativaPiano({
    this.id,
    required this.alimento,
    required this.quantitaG,
  });

  /// Id nel database; `null` per un'alternativa non ancora salvata.
  final String? id;
  final Alimento alimento;
  final double quantitaG;

  AlternativaPiano copyWith({double? quantitaG}) => AlternativaPiano(
    id: id,
    alimento: alimento,
    quantitaG: quantitaG ?? this.quantitaG,
  );
}

/// Alternativa di un pasto con la voce che sostituisce: quello che serve al
/// check-in del paziente (`check_in.alternativa_id` è l'[id] di questa riga).
class AlternativaAmmessa {
  const AlternativaAmmessa({
    required this.id,
    required this.voceId,
    required this.alimentoVoce,
    required this.quantitaVoceG,
    required this.alimento,
    required this.quantitaG,
  });

  final String id;
  final String voceId;

  /// La voce originale del pasto.
  final Alimento alimentoVoce;
  final double quantitaVoceG;

  /// L'alternativa ammessa.
  final Alimento alimento;
  final double quantitaG;
}

/// Voce di un pasto: un alimento con la sua quantità (RF_GP_2).
class VocePiano {
  VocePiano({
    String? chiave,
    required this.alimento,
    required this.quantitaG,
    this.alternative = const [],
  }) : chiave = chiave ?? nuovaChiave();

  final String chiave;
  final Alimento alimento;
  final double quantitaG;
  final List<AlternativaPiano> alternative;

  VocePiano copyWith({
    double? quantitaG,
    List<AlternativaPiano>? alternative,
  }) => VocePiano(
    chiave: chiave,
    alimento: alimento,
    quantitaG: quantitaG ?? this.quantitaG,
    alternative: alternative ?? this.alternative,
  );
}

/// Pasto previsto di un giorno (UC_GP_2).
class PastoPiano {
  PastoPiano({
    String? chiave,
    required this.tipo,
    this.orario,
    this.voci = const [],
  }) : chiave = chiave ?? nuovaChiave();

  final String chiave;
  final TipoPasto tipo;

  /// "HH:mm" o `null`.
  final String? orario;
  final List<VocePiano> voci;

  /// Copia con chiavi nuove (e senza id del database): una copia vera, non un
  /// riferimento, per "copia del giorno" e per i modelli (RF_GP_9, RF_GP_13).
  PastoPiano copia() => PastoPiano(
    tipo: tipo,
    orario: orario,
    voci: [
      for (final v in voci)
        VocePiano(
          alimento: v.alimento,
          quantitaG: v.quantitaG,
          alternative: [
            for (final a in v.alternative)
              AlternativaPiano(alimento: a.alimento, quantitaG: a.quantitaG),
          ],
        ),
    ],
  );

  PastoPiano copyWith({
    String? orario,
    bool senzaOrario = false,
    List<VocePiano>? voci,
  }) => PastoPiano(
    chiave: chiave,
    tipo: tipo,
    orario: senzaOrario ? null : (orario ?? this.orario),
    voci: voci ?? this.voci,
  );
}

class GiornoPiano {
  const GiornoPiano({required this.giornoSettimana, this.pasti = const []});

  /// 1 = lunedì … 7 = domenica.
  final int giornoSettimana;
  final List<PastoPiano> pasti;

  GiornoPiano copyWith({List<PastoPiano>? pasti}) =>
      GiornoPiano(giornoSettimana: giornoSettimana, pasti: pasti ?? this.pasti);
}

/// Una versione del piano alimentare (RF_GP_1, RF_GP_7). Immutabile: ogni
/// modifica dell'editor restituisce un nuovo [PianoAlimentare].
class PianoAlimentare {
  const PianoAlimentare({
    this.id,
    this.versione,
    this.stato = StatoPiano.bozza,
    required this.dataInizio,
    this.giorni = const [],
    this.creatoIl,
  });

  /// `null` finché la versione non è salvata.
  final String? id;
  final int? versione;
  final StatoPiano stato;
  final DateTime dataInizio;
  final List<GiornoPiano> giorni;
  final DateTime? creatoIl;

  GiornoPiano? giorno(int giornoSettimana) {
    for (final g in giorni) {
      if (g.giornoSettimana == giornoSettimana) return g;
    }
    return null;
  }

  PianoAlimentare copyWith({DateTime? dataInizio, List<GiornoPiano>? giorni}) =>
      PianoAlimentare(
        id: id,
        versione: versione,
        stato: stato,
        dataInizio: dataInizio ?? this.dataInizio,
        giorni: giorni ?? this.giorni,
        creatoIl: creatoIl,
      );

  // ---- modifiche dell'editor (restituiscono un nuovo piano) ----

  PianoAlimentare _sulGiorno(
    int giorno,
    GiornoPiano Function(GiornoPiano g) modifica,
  ) => copyWith(
    giorni: [
      for (final g in giorni)
        if (g.giornoSettimana == giorno) modifica(g) else g,
    ],
  );

  PianoAlimentare _sulPasto(
    int giorno,
    String chiavePasto,
    PastoPiano Function(PastoPiano p) modifica,
  ) => _sulGiorno(
    giorno,
    (g) => g.copyWith(
      pasti: [
        for (final p in g.pasti)
          if (p.chiave == chiavePasto) modifica(p) else p,
      ],
    ),
  );

  /// Aggiunge un giorno (in ordine di settimana) con i pasti indicati. Se il
  /// giorno c'è già non cambia nulla.
  PianoAlimentare aggiungiGiorno(int giorno, List<TipoPasto> tipi) {
    if (this.giorno(giorno) != null) return this;
    final nuovo = GiornoPiano(
      giornoSettimana: giorno,
      pasti: [
        for (final t in tipi) PastoPiano(tipo: t, orario: t.orarioPredefinito),
      ],
    );
    return copyWith(
      giorni: [...giorni, nuovo]
        ..sort((a, b) => a.giornoSettimana.compareTo(b.giornoSettimana)),
    );
  }

  PianoAlimentare rimuoviGiorno(int giorno) => copyWith(
    giorni: [
      for (final g in giorni)
        if (g.giornoSettimana != giorno) g,
    ],
  );

  /// Aggiunge un pasto vuoto: va dopo gli altri pasti dello stesso tipo o
  /// precedenti nella giornata (colazione, spuntino, pranzo, merenda, cena).
  PianoAlimentare aggiungiPasto(int giorno, TipoPasto tipo) =>
      _sulGiorno(giorno, (g) {
        final nuovo = PastoPiano(tipo: tipo, orario: tipo.orarioPredefinito);
        var posizione = g.pasti.length;
        for (var i = 0; i < g.pasti.length; i++) {
          if (g.pasti[i].tipo.index > tipo.index) {
            posizione = i;
            break;
          }
        }
        return g.copyWith(pasti: [...g.pasti]..insert(posizione, nuovo));
      });

  PianoAlimentare rimuoviPasto(int giorno, String chiavePasto) => _sulGiorno(
    giorno,
    (g) => g.copyWith(
      pasti: [
        for (final p in g.pasti)
          if (p.chiave != chiavePasto) p,
      ],
    ),
  );

  PianoAlimentare impostaOrario(
    int giorno,
    String chiavePasto,
    String? orario,
  ) => _sulPasto(
    giorno,
    chiavePasto,
    (p) => p.copyWith(orario: orario, senzaOrario: orario == null),
  );

  PianoAlimentare aggiungiVoce(
    int giorno,
    String chiavePasto,
    VocePiano voce,
  ) => _sulPasto(
    giorno,
    chiavePasto,
    (p) => p.copyWith(voci: [...p.voci, voce]),
  );

  PianoAlimentare aggiornaQuantita(
    int giorno,
    String chiavePasto,
    String chiaveVoce,
    double quantitaG,
  ) => _sulPasto(
    giorno,
    chiavePasto,
    (p) => p.copyWith(
      voci: [
        for (final v in p.voci)
          if (v.chiave == chiaveVoce) v.copyWith(quantitaG: quantitaG) else v,
      ],
    ),
  );

  PianoAlimentare rimuoviVoce(
    int giorno,
    String chiavePasto,
    String chiaveVoce,
  ) => _sulPasto(
    giorno,
    chiavePasto,
    (p) => p.copyWith(
      voci: [
        for (final v in p.voci)
          if (v.chiave != chiaveVoce) v,
      ],
    ),
  );

  /// Imposta le alternative ammesse di una voce (RF_GP_6): una o più, oppure
  /// nessuna.
  PianoAlimentare impostaAlternative(
    int giorno,
    String chiavePasto,
    String chiaveVoce,
    List<AlternativaPiano> alternative,
  ) => _sullaVoce(
    giorno,
    chiavePasto,
    chiaveVoce,
    (v) => v.copyWith(alternative: List.unmodifiable(alternative)),
  );

  PianoAlimentare _sullaVoce(
    int giorno,
    String chiavePasto,
    String chiaveVoce,
    VocePiano Function(VocePiano v) modifica,
  ) => _sulPasto(
    giorno,
    chiavePasto,
    (p) => p.copyWith(
      voci: [
        for (final v in p.voci)
          if (v.chiave == chiaveVoce) modifica(v) else v,
      ],
    ),
  );

  /// Giorni di [destinazioni] che hanno già degli alimenti: copiarci sopra li
  /// sostituisce, quindi prima si chiede conferma (RF_GP_13). Un giorno con
  /// soli pasti vuoti non perde nulla e non conta.
  List<int> giorniConAlimenti(Iterable<int> destinazioni) => [
    for (final g in destinazioni)
      if (giorno(g)?.pasti.any((p) => p.voci.isNotEmpty) ?? false) g,
  ];

  /// Copia profonda del giorno [da] (pasti, voci e alternative) su ogni
  /// giorno di [a]: sostituisce i pasti dei giorni che già ci sono e crea
  /// quelli che mancano (RF_GP_13).
  PianoAlimentare copiaGiorno(int da, Iterable<int> a) {
    final origine = giorno(da);
    if (origine == null) return this;
    final destinazioni = {
      for (final g in a)
        if (g != da) g,
    };
    final nuovi = <GiornoPiano>[
      for (final g in giorni)
        if (destinazioni.contains(g.giornoSettimana))
          GiornoPiano(
            giornoSettimana: g.giornoSettimana,
            pasti: [for (final p in origine.pasti) p.copia()],
          )
        else
          g,
      for (final g in destinazioni)
        if (giorno(g) == null)
          GiornoPiano(
            giornoSettimana: g,
            pasti: [for (final p in origine.pasti) p.copia()],
          ),
    ]..sort((x, y) => x.giornoSettimana.compareTo(y.giornoSettimana));
    return copyWith(giorni: nuovi);
  }

  /// Inserisce una copia di [pasto] nel giorno, al suo posto nella giornata
  /// (da un pasto salvato, RF_GP_9).
  PianoAlimentare inserisciPasto(int giorno, PastoPiano pasto) =>
      _sulGiorno(giorno, (g) {
        final copia = pasto.copia();
        var posizione = g.pasti.length;
        for (var i = 0; i < g.pasti.length; i++) {
          if (g.pasti[i].tipo.index > copia.tipo.index) {
            posizione = i;
            break;
          }
        }
        return g.copyWith(pasti: [...g.pasti]..insert(posizione, copia));
      });

  /// Sposta una voce da [da] a [a] (indici come in `ReorderableListView`
  /// dopo la correzione: [a] è la posizione finale).
  PianoAlimentare spostaVoce(int giorno, String chiavePasto, int da, int a) =>
      _sulPasto(giorno, chiavePasto, (p) {
        if (da < 0 || da >= p.voci.length || a < 0 || a >= p.voci.length) {
          return p;
        }
        final voci = [...p.voci];
        voci.insert(a, voci.removeAt(da));
        return p.copyWith(voci: voci);
      });
}

/// Riepilogo di una versione, per l'elenco dello storico (RF_GP_7).
class VersionePiano {
  const VersionePiano({
    required this.id,
    required this.versione,
    required this.stato,
    required this.dataInizio,
    this.creatoIl,
  });

  final String id;
  final int versione;
  final StatoPiano stato;
  final DateTime? dataInizio;
  final DateTime? creatoIl;
}
