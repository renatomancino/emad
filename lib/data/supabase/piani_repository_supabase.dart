import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/modelli/alimento.dart';
import '../../domain/modelli/piano_alimentare.dart';
import '../../domain/repository/pazienti_repository.dart';
import '../../domain/repository/piani_repository.dart';
import 'pazienti_repository_supabase.dart' show traduciErrore;

/// Piano con tutta la struttura in una sola richiesta (la RLS decide cosa si
/// vede: il nutrizionista autore tutte le versioni, il paziente quelle assegnate).
const _selezionePiano =
    'id, versione, stato, data_inizio, creato_il, '
    'giorni(id, giorno_settimana, '
    'pasti(id, tipo, orario, ordine, '
    'voci_pasto(id, quantita_g, ordine, alimento:alimenti(*), '
    'alternative(id, quantita_g, alimento:alimenti(*)))))';

/// Corpo della RPC `salva_piano` (008): giorni → pasti → voci → alternative.
/// Gli id locali non partono: il database ricrea tutto in una nuova versione
/// e ricalcola kcal e macro dai valori per 100 g.
Map<String, dynamic> strutturaPerSalvataggio(PianoAlimentare piano) => {
  'giorni': [
    for (final g in piano.giorni)
      {
        'giorno': g.giornoSettimana,
        'pasti': [
          for (final p in g.pasti)
            {
              'tipo': p.tipo.valoreDb,
              'orario': p.orario,
              'voci': [
                for (final v in p.voci)
                  {
                    'alimento_id': v.alimento.id,
                    'quantita_g': v.quantitaG,
                    if (v.alternative.isNotEmpty)
                      'alternative': [
                        for (final a in v.alternative)
                          {
                            'alimento_id': a.alimento.id,
                            'quantita_g': a.quantitaG,
                          },
                      ],
                  },
              ],
            },
        ],
      },
  ],
};

/// Legge una riga di `piani` con le tabelle annidate di [_selezionePiano].
PianoAlimentare pianoDaRiga(Map<String, dynamic> r) {
  double numero(Object? v) => v is num ? v.toDouble() : double.parse('$v');
  int ordine(Map m) => (m['ordine'] as num?)?.toInt() ?? 0;
  String? orario(Object? v) =>
      v is String && v.length >= 5 ? v.substring(0, 5) : null;

  final giorni = <GiornoPiano>[
    for (final g in (r['giorni'] as List? ?? const []).cast<Map>())
      GiornoPiano(
        giornoSettimana: (g['giorno_settimana'] as num).toInt(),
        pasti: [
          for (final p
              in ((g['pasti'] as List? ?? const []).cast<Map>().toList()
                ..sort((a, b) => ordine(a).compareTo(ordine(b)))))
            PastoPiano(
              chiave: p['id'] as String,
              tipo: TipoPasto.daDb(p['tipo'] as String?),
              orario: orario(p['orario']),
              voci: [
                for (final v
                    in ((p['voci_pasto'] as List? ?? const [])
                        .cast<Map>()
                        .toList()
                      ..sort((a, b) => ordine(a).compareTo(ordine(b)))))
                  VocePiano(
                    chiave: v['id'] as String,
                    alimento: Alimento.daRiga(
                      Map<String, dynamic>.from(v['alimento'] as Map),
                    ),
                    quantitaG: numero(v['quantita_g']),
                    alternative: [
                      for (final a
                          in (v['alternative'] as List? ?? const [])
                              .cast<Map>())
                        AlternativaPiano(
                          alimento: Alimento.daRiga(
                            Map<String, dynamic>.from(a['alimento'] as Map),
                          ),
                          quantitaG: numero(a['quantita_g']),
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
  ]..sort((a, b) => a.giornoSettimana.compareTo(b.giornoSettimana));

  return PianoAlimentare(
    id: r['id'] as String,
    versione: (r['versione'] as num).toInt(),
    stato: StatoPiano.daDb(r['stato'] as String?),
    dataInizio:
        DateTime.tryParse((r['data_inizio'] as String?) ?? '') ??
        DateTime.now(),
    giorni: giorni,
    creatoIl: DateTime.tryParse((r['creato_il'] as String?) ?? ''),
  );
}

/// [PianiRepository] su Supabase: letture con RLS e salvataggio con la RPC
/// transazionale `salva_piano` (migrazione 008).
class PianiRepositorySupabase extends PianiRepository {
  PianiRepositorySupabase(this._db);

  final SupabaseClient _db;

  Future<T> _chiama<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      if (e is ErroreOperazione) rethrow;
      throw traduciErrore(e);
    }
  }

  @override
  Future<PianoAlimentare?> corrente(String pazienteId) => _chiama(() async {
    final riga = await _db
        .from('piani')
        .select(_selezionePiano)
        .eq('paziente_id', pazienteId)
        .eq('stato', 'corrente')
        .maybeSingle();
    return riga == null ? null : pianoDaRiga(riga);
  });

  @override
  Future<List<VersionePiano>> versioni(String pazienteId) => _chiama(() async {
    final righe = await _db
        .from('piani')
        .select('id, versione, stato, data_inizio, creato_il')
        .eq('paziente_id', pazienteId)
        .order('versione', ascending: false);
    return [
      for (final r in righe)
        VersionePiano(
          id: r['id'] as String,
          versione: (r['versione'] as num).toInt(),
          stato: StatoPiano.daDb(r['stato'] as String?),
          dataInizio: DateTime.tryParse((r['data_inizio'] as String?) ?? ''),
          creatoIl: DateTime.tryParse((r['creato_il'] as String?) ?? ''),
        ),
    ];
  });

  @override
  Future<PianoAlimentare> versione(String pianoId) => _chiama(() async {
    final riga = await _db
        .from('piani')
        .select(_selezionePiano)
        .eq('id', pianoId)
        .single();
    return pianoDaRiga(riga);
  });

  @override
  Future<PianoAlimentare> salva(String pazienteId, PianoAlimentare piano) =>
      _chiama(() async {
        final d = piano.dataInizio;
        final id = await _db.rpc(
          'salva_piano',
          params: {
            'p_paziente': pazienteId,
            'p_data_inizio':
                '${d.year.toString().padLeft(4, '0')}-'
                '${d.month.toString().padLeft(2, '0')}-'
                '${d.day.toString().padLeft(2, '0')}',
            'p_struttura': strutturaPerSalvataggio(piano),
          },
        );
        final salvato = await versione(id as String);
        notifyListeners();
        return salvato;
      });
}
