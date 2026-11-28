import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/regole/validazione.dart';
import '../../domain/repository/collegamento_repository.dart';
import 'pazienti_repository_supabase.dart';

/// [CollegamentoRepository] su Supabase: `verifica_invito` (anche senza
/// login) e `accetta_invito`. Nessuna scrittura diretta su pazienti/inviti.
class CollegamentoRepositorySupabase implements CollegamentoRepository {
  CollegamentoRepositorySupabase(this._db);

  final SupabaseClient _db;

  @override
  Future<AnteprimaInvito> verifica(String codice) async {
    try {
      final righe = await _db.rpc(
        'verifica_invito',
        params: {'p_codice': Validazione.normalizzaCodice(codice)},
      );
      final r = (righe as List).first as Map<String, dynamic>;
      return AnteprimaInvito(
        nomeNutrizionista: r['nome_nutrizionista'] as String,
        scadenza: DateTime.parse(r['scadenza'] as String).toLocal(),
      );
    } catch (e) {
      throw traduciErrore(e);
    }
  }

  @override
  Future<void> accetta(String codice) async {
    try {
      await _db.rpc(
        'accetta_invito',
        params: {'p_codice': Validazione.normalizzaCodice(codice)},
      );
    } catch (e) {
      throw traduciErrore(e);
    }
  }

  @override
  Future<String?> mioPazienteId() async {
    final utente = _db.auth.currentUser;
    if (utente == null) return null;
    try {
      // Stessa lettura di `_leggiCollegamento` dell'autenticazione, ma
      // restituisce l'id: la policy `pazienti_select_paz` mostra al paziente
      // solo le proprie righe.
      final riga = await _db
          .from('pazienti')
          .select('id')
          .eq('utente_id', utente.id)
          .eq('stato', 'attivo')
          .limit(1)
          .maybeSingle();
      return riga?['id'] as String?;
    } catch (e) {
      throw traduciErrore(e);
    }
  }
}
