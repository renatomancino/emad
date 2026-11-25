import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/modelli/obiettivi.dart';
import '../../domain/repository/obiettivi_repository.dart';
import '../../domain/repository/pazienti_repository.dart';
import 'pazienti_repository_supabase.dart' show traduciErrore;

const _colonne = 'id, kcal, proteine_g, carboidrati_g, grassi_g, data_inizio';

/// [ObiettiviRepository] sulla tabella `obiettivi`. L'accesso è deciso dalle
/// policy RLS (002): il nutrizionista legge e scrive solo per i propri
/// pazienti, il paziente legge solo i propri.
class ObiettiviRepositorySupabase extends ObiettiviRepository {
  ObiettiviRepositorySupabase(this._db);

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
  Future<Obiettivi?> corrente(String pazienteId) => _chiama(() async {
    final riga = await _db
        .from('obiettivi')
        .select(_colonne)
        .eq('paziente_id', pazienteId)
        .order('data_inizio', ascending: false)
        .order('creato_il', ascending: false)
        .limit(1)
        .maybeSingle();
    return riga == null ? null : _daRiga(riga);
  });

  @override
  Future<List<Obiettivi>> storico(String pazienteId) => _chiama(() async {
    final righe = await _db
        .from('obiettivi')
        .select(_colonne)
        .eq('paziente_id', pazienteId)
        .order('data_inizio', ascending: false)
        .order('creato_il', ascending: false);
    return [for (final r in righe) _daRiga(r)];
  });

  @override
  Future<Obiettivi> imposta(
    String pazienteId, {
    required int kcal,
    required double proteineG,
    required double carboidratiG,
    required double grassiG,
  }) => _chiama(() async {
    final riga = await _db
        .from('obiettivi')
        .insert({
          'paziente_id': pazienteId,
          'kcal': kcal,
          'proteine_g': proteineG,
          'carboidrati_g': carboidratiG,
          'grassi_g': grassiG,
        })
        .select(_colonne)
        .single();
    notifyListeners();
    return _daRiga(riga);
  });

  static Obiettivi _daRiga(Map<String, dynamic> r) => Obiettivi(
    id: r['id'] as String?,
    kcal: (r['kcal'] as num).toInt(),
    proteineG: (r['proteine_g'] as num).toDouble(),
    carboidratiG: (r['carboidrati_g'] as num).toDouble(),
    grassiG: (r['grassi_g'] as num).toDouble(),
    dal: DateTime.parse(r['data_inizio'] as String),
  );
}
