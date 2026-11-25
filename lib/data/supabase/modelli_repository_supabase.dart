import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/modelli/modello_piano.dart';
import '../../domain/modelli/piano_alimentare.dart';
import '../../domain/regole/calcoli_piano.dart';
import '../../domain/repository/modelli_repository.dart';
import '../../domain/repository/pazienti_repository.dart';
import 'pazienti_repository_supabase.dart' show traduciErrore;

const _colonne = 'id, nome, tipo, contenuto, creato_il';

/// [ModelliRepository] sulla tabella `modelli_piano`. La policy RLS
/// `modelli_piano_nut` (002) dà accesso solo al nutrizionista proprietario.
class ModelliRepositorySupabase extends ModelliRepository {
  /// [idUtente] restituisce l'id dell'utente connesso (predefinito: quello
  /// della sessione Supabase); lo si passa nei test.
  ModelliRepositorySupabase(this._db, {String? Function()? idUtente})
    : _idUtente = idUtente ?? (() => _db.auth.currentUser?.id);

  final SupabaseClient _db;
  final String? Function() _idUtente;

  Future<T> _chiama<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      if (e is ErroreOperazione) rethrow;
      throw traduciErrore(e);
    }
  }

  static ModelloPiano _daRiga(Map<String, dynamic> r) => ModelloPiano(
    id: r['id'] as String,
    nome: r['nome'] as String,
    tipo: TipoModello.daDb(r['tipo'] as String?),
    contenuto: Map<String, dynamic>.from(r['contenuto'] as Map),
    creatoIl: DateTime.tryParse((r['creato_il'] as String?) ?? ''),
  );

  @override
  Future<List<ModelloPiano>> elenco(TipoModello tipo) => _chiama(() async {
    final righe = await _db
        .from('modelli_piano')
        .select(_colonne)
        .eq('tipo', tipo.valoreDb)
        .order('creato_il', ascending: false);
    return [for (final r in righe) _daRiga(r)];
  });

  Future<ModelloPiano> _salva(
    String nome,
    TipoModello tipo,
    Map<String, dynamic> contenuto,
  ) => _chiama(() async {
    final errore = validaNomeModello(nome);
    if (errore != null) throw ErroreOperazione(errore, codice: 'nome');
    final utente = _idUtente();
    if (utente == null) {
      throw const ErroreOperazione(
        'Sessione scaduta: accedi di nuovo.',
        codice: 'sessione',
      );
    }
    final riga = await _db
        .from('modelli_piano')
        .insert({
          'nutrizionista_id': utente,
          'nome': nome.trim(),
          'tipo': tipo.valoreDb,
          'contenuto': contenuto,
        })
        .select(_colonne)
        .single();
    notifyListeners();
    return _daRiga(riga);
  });

  @override
  Future<ModelloPiano> salvaPasto(String nome, PastoPiano pasto) =>
      _salva(nome, TipoModello.pasto, contenutoDaPasto(pasto));

  @override
  Future<ModelloPiano> salvaPiano(String nome, PianoAlimentare piano) =>
      _salva(nome, TipoModello.piano, contenutoDaPiano(piano));

  @override
  Future<void> elimina(String modelloId) => _chiama(() async {
    await _db.from('modelli_piano').delete().eq('id', modelloId);
    notifyListeners();
  });
}
