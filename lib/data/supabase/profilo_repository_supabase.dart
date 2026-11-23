import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/modelli/dati_profilo.dart';
import '../../domain/modelli/profilo.dart';
import '../../domain/repository/auth_repository.dart';
import '../../domain/repository/pazienti_repository.dart';
import '../../domain/repository/profilo_repository.dart';
import 'pazienti_repository_supabase.dart';

/// [ProfiloRepository] su Supabase. Le modifiche passano dalle policy RLS e
/// dai privilegi per colonna (002_rls.sql): ognuno modifica solo i propri
/// dati e mai ruolo, piano o nutrizionista.
class ProfiloRepositorySupabase extends ProfiloRepository {
  ProfiloRepositorySupabase(this._db, this._auth);

  final SupabaseClient _db;
  final AuthRepository _auth;

  String get _id {
    final utente = _db.auth.currentUser;
    if (utente == null) {
      throw const ErroreOperazione(
        'Sessione scaduta: accedi di nuovo.',
        codice: 'sessione',
      );
    }
    return utente.id;
  }

  Future<T> _chiama<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      if (e is ErroreOperazione) rethrow;
      throw traduciErrore(e);
    }
  }

  @override
  Future<DatiProfilo> leggi() => _chiama(() async {
    final id = _id;
    final profilo = await _db
        .from('profili')
        .select('nome')
        .eq('id', id)
        .single();
    final nome = (profilo['nome'] as String?) ?? '';

    if (_auth.ruolo == Ruolo.nutrizionista) {
      final n = await _db
          .from('nutrizionisti')
          .select('titolo')
          .eq('id', id)
          .maybeSingle();
      return DatiProfilo(nome: nome, titolo: n?['titolo'] as String?);
    }
    final p = await _db
        .from('pazienti')
        .select('altezza_cm, data_nascita, obiettivo')
        .eq('utente_id', id)
        .eq('stato', 'attivo')
        .maybeSingle();
    return DatiProfilo(
      nome: nome,
      altezzaCm: (p?['altezza_cm'] as num?)?.toDouble(),
      dataNascita: DateTime.tryParse((p?['data_nascita'] as String?) ?? ''),
      obiettivo: p?['obiettivo'] as String?,
    );
  });

  @override
  Future<void> salva(DatiProfilo dati) => _chiama(() async {
    final id = _id;
    await _db.from('profili').update({'nome': dati.nome.trim()}).eq('id', id);

    if (_auth.ruolo == Ruolo.nutrizionista) {
      final titolo = dati.titolo?.trim();
      await _db
          .from('nutrizionisti')
          .update({'titolo': titolo == null || titolo.isEmpty ? null : titolo})
          .eq('id', id);
    } else if (_auth.collegato) {
      final obiettivo = dati.obiettivo?.trim();
      await _db
          .from('pazienti')
          .update({
            'altezza_cm': dati.altezzaCm,
            'data_nascita': dati.dataNascita == null
                ? null
                : _data(dati.dataNascita!),
            'obiettivo': obiettivo == null || obiettivo.isEmpty
                ? null
                : obiettivo,
          })
          .eq('utente_id', id)
          .eq('stato', 'attivo');
    }
    await _auth.ricaricaProfilo();
    notifyListeners();
  });

  @override
  Future<void> eliminaAccount() => _chiama(() async {
    await _db.rpc('elimina_account');
    // L'utente non esiste più: si svuota la sessione sul dispositivo.
    await _auth.chiudiSessioneLocale();
  });

  static String _data(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
