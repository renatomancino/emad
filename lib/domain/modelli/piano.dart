/// Piani di abbonamento del nutrizionista (RF_GAD_4, RF_GAD_5).
/// Prezzi in centesimi, IVA esclusa (CLAUDE.md regola 4). Gli stessi valori
/// sono nel database: `limite_pazienti()` e `prezzo_piano()` (supabase/migrations).
enum PianoAbbonamento {
  free(etichetta: 'Free', limite: 1, mensileCent: 0, annualeCent: 0),
  start(etichetta: 'Start', limite: 5, mensileCent: 1200, annualeCent: 12000),
  pro(etichetta: 'Pro', limite: null, mensileCent: 2500, annualeCent: 25000);

  const PianoAbbonamento({
    required this.etichetta,
    required this.limite,
    required this.mensileCent,
    required this.annualeCent,
  });

  final String etichetta;

  /// Numero massimo di posti; `null` = illimitati (Pro).
  final int? limite;
  final int mensileCent;
  final int annualeCent;

  int prezzoCent(PeriodoFatturazione periodo) =>
      periodo == PeriodoFatturazione.annuale ? annualeCent : mensileCent;

  /// Descrizione del limite per l'interfaccia.
  String get descrizioneLimite => switch (this) {
    PianoAbbonamento.free => '1 paziente a vita',
    PianoAbbonamento.start => 'Fino a 5 pazienti attivi',
    PianoAbbonamento.pro => 'Pazienti illimitati',
  };

  static PianoAbbonamento daDb(String? valore) => PianoAbbonamento.values
      .firstWhere((p) => p.name == valore, orElse: () => PianoAbbonamento.free);
}

enum PeriodoFatturazione {
  mensile('al mese'),
  annuale('all\'anno');

  const PeriodoFatturazione(this.suffisso);

  final String suffisso;

  static PeriodoFatturazione? daDb(String? valore) {
    for (final p in PeriodoFatturazione.values) {
      if (p.name == valore) return p;
    }
    return null;
  }
}

/// Prezzo in euro per l'interfaccia, es. "12 €" o "120 €".
String formattaEuro(int centesimi) {
  final euro = centesimi ~/ 100;
  final resto = centesimi % 100;
  return resto == 0 ? '$euro €' : '$euro,${resto.toString().padLeft(2, '0')} €';
}

/// Stato dell'abbonamento letto dal back-end (RPC `stato_abbonamento`).
class StatoAbbonamento {
  const StatoAbbonamento({
    required this.piano,
    required this.periodo,
    required this.pazientiAttivi,
    required this.pazientiCollegatiTotali,
    required this.invitiInAttesa,
  });

  final PianoAbbonamento piano;
  final PeriodoFatturazione? periodo;
  final int pazientiAttivi;

  /// Pazienti che hanno accettato un invito, anche se poi archiviati (Free).
  final int pazientiCollegatiTotali;
  final int invitiInAttesa;

  factory StatoAbbonamento.daRiga(Map<String, dynamic> r) => StatoAbbonamento(
    piano: PianoAbbonamento.daDb(r['piano'] as String?),
    periodo: PeriodoFatturazione.daDb(r['periodo'] as String?),
    pazientiAttivi: (r['pazienti_attivi'] as num?)?.toInt() ?? 0,
    pazientiCollegatiTotali:
        (r['pazienti_collegati_totali'] as num?)?.toInt() ?? 0,
    invitiInAttesa: (r['inviti_in_attesa'] as num?)?.toInt() ?? 0,
  );
}
