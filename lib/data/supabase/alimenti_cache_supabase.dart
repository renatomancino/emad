import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/modelli/alimento.dart';
import '../../domain/repository/pazienti_repository.dart';
import '../alimenti_cache.dart';
import 'pazienti_repository_supabase.dart' show traduciErrore;

/// Uso di un alimento da parte del nutrizionista (tabella
/// `alimenti_nutrizionista`, migrazione 006).
typedef UsoAlimento = ({bool preferito, DateTime? ultimoUso});

/// [AlimentiCache] su Supabase: la cache condivisa `alimenti` e, per ogni
/// nutrizionista, recenti e preferiti in `alimenti_nutrizionista`. L'accesso
/// è deciso dalle policy RLS (002 e 006).
class AlimentiCacheSupabase implements AlimentiCache {
  /// [idUtente] restituisce l'id dell'utente connesso (predefinito: quello
  /// della sessione Supabase); lo si passa nei test.
  AlimentiCacheSupabase(this._db, {String? Function()? idUtente})
    : _idUtente = idUtente ?? (() => _db.auth.currentUser?.id);

  final SupabaseClient _db;
  final String? Function() _idUtente;

  String get _utente {
    final id = _idUtente();
    if (id == null) {
      throw const ErroreOperazione(
        'Sessione scaduta: accedi di nuovo.',
        codice: 'sessione',
      );
    }
    return id;
  }

  Future<T> _chiama<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      if (e is ErroreOperazione) rethrow;
      throw traduciErrore(e);
    }
  }

  /// Rende letterali `%`, `_` e `\` in un modello di `ilike`.
  static String escapeLike(String testo) => testo
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  /// Preferiti prima, poi i più recenti, poi il nome (come in memoria).
  static List<Alimento> ordina(
    List<Alimento> alimenti,
    Map<String, UsoAlimento> uso,
  ) {
    final conFlag = [
      for (final a in alimenti)
        a.copyWith(preferito: uso[a.id]?.preferito ?? false),
    ];
    conFlag.sort((a, b) {
      if (a.preferito != b.preferito) return a.preferito ? -1 : 1;
      final ua = uso[a.id]?.ultimoUso, ub = uso[b.id]?.ultimoUso;
      if (ua != null || ub != null) {
        if (ua == null) return 1;
        if (ub == null) return -1;
        final c = ub.compareTo(ua);
        if (c != 0) return c;
      }
      return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
    });
    return conFlag;
  }

  @override
  Future<List<Alimento>> cercaPerNome(String testo, {int limite = 20}) =>
      _chiama(() async {
        final t = testo.trim();
        if (t.isEmpty) return const [];
        final righe = await _db
            .from('alimenti')
            .select()
            .ilike('nome', '%${escapeLike(t)}%')
            .order('nome')
            .limit(200);
        final alimenti = [for (final r in righe) Alimento.daRiga(r)];
        if (alimenti.isEmpty) return alimenti;

        final righeUso = await _db
            .from('alimenti_nutrizionista')
            .select('alimento_id, preferito, ultimo_uso')
            .inFilter('alimento_id', [for (final a in alimenti) a.id!]);
        final uso = <String, UsoAlimento>{
          for (final r in righeUso)
            r['alimento_id'] as String: (
              preferito: r['preferito'] == true,
              ultimoUso: DateTime.tryParse('${r['ultimo_uso']}'),
            ),
        };
        return ordina(alimenti, uso).take(limite).toList();
      });

  @override
  Future<Alimento> salva(Alimento alimento) => _chiama(() async {
    final daOnline = alimento.fonte == FonteAlimento.openFoodFacts;
    if (daOnline) {
      final esistente = await _cercaEsistente(alimento);
      if (esistente != null) return esistente;
    }
    final riga = alimento.perInserimento(
      // L'alimento di Open Food Facts è della cache condivisa; quello
      // personalizzato porta il nome di chi lo ha creato.
      creatoDa: daOnline ? null : _utente,
    );
    try {
      final inserito = await _db
          .from('alimenti')
          .insert(riga)
          .select()
          .single();
      return Alimento.daRiga(inserito);
    } on PostgrestException catch (e) {
      // Un altro dispositivo lo ha salvato un attimo prima: si riusa.
      if (e.code == '23505' && daOnline) {
        final esistente = await _cercaEsistente(alimento);
        if (esistente != null) return esistente;
      }
      rethrow;
    }
  });

  Future<Alimento?> _cercaEsistente(Alimento a) async {
    final base = _db.from('alimenti').select();
    final Map<String, dynamic>? riga;
    if (a.codiceBarre != null) {
      riga = await base.eq('codice_barre', a.codiceBarre!).maybeSingle();
    } else {
      var q = base
          .eq('fonte', FonteAlimento.openFoodFacts.valoreDb)
          .ilike('nome', escapeLike(a.nome));
      q = a.marca == null
          ? q.isFilter('marca', null)
          : q.ilike('marca', escapeLike(a.marca!));
      riga = await q.limit(1).maybeSingle();
    }
    return riga == null ? null : Alimento.daRiga(riga);
  }

  @override
  Future<void> segnaUso(String alimentoId) => _chiama(() async {
    await _db.from('alimenti_nutrizionista').upsert({
      'nutrizionista_id': _utente,
      'alimento_id': alimentoId,
      'ultimo_uso': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'nutrizionista_id,alimento_id');
  });

  List<Alimento> _daRigheUso(List<Map<String, dynamic>> righe) => [
    for (final r in righe)
      if (r['alimenti'] is Map<String, dynamic>)
        Alimento.daRiga(
          r['alimenti'] as Map<String, dynamic>,
          preferito: r['preferito'] == true,
        ),
  ];

  @override
  Future<List<Alimento>> recenti({int limite = 10}) => _chiama(() async {
    final righe = await _db
        .from('alimenti_nutrizionista')
        .select('preferito, alimenti(*)')
        .eq('nutrizionista_id', _utente)
        .order('ultimo_uso', ascending: false)
        .limit(limite);
    return _daRigheUso(righe);
  });

  @override
  Future<List<Alimento>> preferiti() => _chiama(() async {
    final righe = await _db
        .from('alimenti_nutrizionista')
        .select('preferito, alimenti(*)')
        .eq('nutrizionista_id', _utente)
        .eq('preferito', true)
        .order('ultimo_uso', ascending: false);
    return _daRigheUso(righe);
  });

  @override
  Future<void> impostaPreferito(String alimentoId, bool preferito) =>
      _chiama(() async {
        await _db.from('alimenti_nutrizionista').upsert({
          'nutrizionista_id': _utente,
          'alimento_id': alimentoId,
          'preferito': preferito,
        }, onConflict: 'nutrizionista_id,alimento_id');
      });
}
