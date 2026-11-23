import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/modelli/paziente.dart';
import '../../domain/modelli/piano.dart';
import '../../domain/repository/pazienti_repository.dart';

/// Traduce gli errori del back-end (codici CN00x delle RPC, vedi
/// supabase/migrations/002_rls.sql) in errori dell'app.
Exception traduciErrore(Object e) {
  if (e is PostgrestException) {
    if (e.code == 'CN001') {
      return ErroreLimitePiano(
        e.message,
        suggerimento: e.hint,
        piano: e.details == null
            ? null
            : PianoAbbonamento.daDb(e.details.toString()),
      );
    }
    if (e.code != null && e.code!.startsWith('CN')) {
      return ErroreOperazione(e.message, codice: e.code);
    }
    debugPrint('Errore del database: ${e.code}');
    return const ErroreOperazione(
      'Operazione non riuscita. Riprova tra poco.',
      codice: 'db',
    );
  }
  debugPrint('Errore di rete: ${e.runtimeType}');
  return const ErroreOperazione(
    'Connessione non riuscita. Controlla la rete e riprova.',
    codice: 'rete',
  );
}

Future<T> _chiama<T>(Future<T> Function() f) async {
  try {
    return await f();
  } catch (e) {
    throw traduciErrore(e);
  }
}

/// [PazientiRepository] su Supabase: letture con RLS, modifiche con le RPC.
class PazientiRepositorySupabase extends PazientiRepository {
  PazientiRepositorySupabase(this._db);

  final SupabaseClient _db;

  @override
  Future<List<PazienteElenco>> elencoPazienti() => _chiama(() async {
    final righe = await _db
        .from('pazienti')
        .select(
          'id, stato, nome, data_collegamento, archiviato_da, '
          'profilo:profili!pazienti_utente_id_fkey(nome)',
        )
        .order('creato_il');
    return [
      for (final r in righe)
        PazienteElenco(
          id: r['id'] as String,
          nome:
              ((r['profilo'] as Map?)?['nome'] as String?) ??
              (r['nome'] as String?) ??
              'Paziente invitato',
          stato: StatoPaziente.daDb(r['stato'] as String?),
          dataCollegamento: DateTime.tryParse(
            (r['data_collegamento'] as String?) ?? '',
          ),
          archiviatoDalPaziente: r['archiviato_da'] == 'paziente',
        ),
    ];
  });

  @override
  Future<List<Invito>> elencoInviti() => _chiama(() async {
    final righe = await _db
        .from('inviti')
        .select(
          'id, codice, stato, scadenza, '
          'paziente:pazienti!inviti_paziente_id_fkey(nome)',
        )
        .order('creato_il', ascending: false);
    return [
      for (final r in righe)
        Invito(
          id: r['id'] as String,
          codice: r['codice'] as String,
          stato: StatoInvito.daDb(r['stato'] as String?),
          scadenza: DateTime.parse(r['scadenza'] as String).toLocal(),
          nome: (r['paziente'] as Map?)?['nome'] as String?,
        ),
    ];
  });

  @override
  Future<Invito> creaInvito({String? nome}) => _chiama(() async {
    final righe = await _db.rpc('crea_invito', params: {'p_nome': nome});
    final r = (righe as List).first as Map<String, dynamic>;
    notifyListeners();
    return Invito(
      id: r['invito_id'] as String,
      codice: r['codice'] as String,
      stato: StatoInvito.creato,
      scadenza: DateTime.parse(r['scadenza'] as String).toLocal(),
      nome: nome,
    );
  });

  @override
  Future<void> revocaInvito(String invitoId) =>
      _modifica(() => _db.rpc('revoca_invito', params: {'p_invito': invitoId}));

  @override
  Future<void> archivia(String pazienteId) => _modifica(
    () => _db.rpc('archivia_paziente', params: {'p_paziente': pazienteId}),
  );

  @override
  Future<void> riattiva(String pazienteId) => _modifica(
    () => _db.rpc('riattiva_paziente', params: {'p_paziente': pazienteId}),
  );

  @override
  Future<void> scollegati() => _modifica(() => _db.rpc('scollega_paziente'));

  Future<void> _modifica(Future<Object?> Function() f) async {
    await _chiama(f);
    notifyListeners();
  }
}

/// [AbbonamentoRepository] su Supabase (RPC `stato_abbonamento`, `cambia_piano`).
class AbbonamentoRepositorySupabase extends AbbonamentoRepository {
  AbbonamentoRepositorySupabase(this._db);

  final SupabaseClient _db;

  @override
  Future<StatoAbbonamento> stato() => _chiama(() async {
    final righe = await _db.rpc('stato_abbonamento');
    return StatoAbbonamento.daRiga(
      (righe as List).first as Map<String, dynamic>,
    );
  });

  @override
  Future<void> cambiaPiano(
    PianoAbbonamento piano,
    PeriodoFatturazione? periodo,
  ) async {
    await _chiama(
      () => _db.rpc(
        'cambia_piano',
        params: {'p_piano': piano.name, 'p_periodo': periodo?.name},
      ),
    );
    notifyListeners();
  }
}
