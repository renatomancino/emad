import '../../domain/modelli/piano_alimentare.dart';
import '../../domain/regole/calcoli_piano.dart';
import '../../domain/repository/pazienti_repository.dart';
import '../../domain/repository/piani_repository.dart';

/// Piani in memoria, senza Supabase (test e `CENATO_RUOLO_FINTO`). Applica le
/// stesse regole di `salva_piano`: nuova versione, una sola corrente.
class PianiRepositoryFinto extends PianiRepository {
  PianiRepositoryFinto({Map<String, List<PianoAlimentare>>? iniziali})
    : _versioni = {
        for (final e in (iniziali ?? {}).entries) e.key: [...e.value],
      };

  /// Per paziente, dalla versione più vecchia alla più recente.
  final Map<String, List<PianoAlimentare>> _versioni;

  /// Con `true` le operazioni falliscono come un errore di rete (per i test).
  bool nonRaggiungibile = false;

  /// Numero di salvataggi andati a buon fine.
  int salvataggi = 0;

  void _controlla() {
    if (nonRaggiungibile) {
      throw const ErroreOperazione(
        'Connessione non riuscita. Controlla la rete e riprova.',
        codice: 'rete',
      );
    }
  }

  @override
  Future<PianoAlimentare?> corrente(String pazienteId) async {
    _controlla();
    for (final p
        in (_versioni[pazienteId] ?? const <PianoAlimentare>[]).reversed) {
      if (p.stato == StatoPiano.corrente) return p;
    }
    return null;
  }

  @override
  Future<List<VersionePiano>> versioni(String pazienteId) async {
    _controlla();
    return [
      for (final p
          in (_versioni[pazienteId] ?? const <PianoAlimentare>[]).reversed)
        VersionePiano(
          id: p.id!,
          versione: p.versione!,
          stato: p.stato,
          dataInizio: p.dataInizio,
          creatoIl: p.creatoIl,
        ),
    ];
  }

  @override
  Future<PianoAlimentare> versione(String pianoId) async {
    _controlla();
    for (final lista in _versioni.values) {
      for (final p in lista) {
        if (p.id == pianoId) return p;
      }
    }
    throw const ErroreOperazione('Versione del piano non trovata.');
  }

  @override
  Future<PianoAlimentare> salva(
    String pazienteId,
    PianoAlimentare piano,
  ) async {
    _controlla();
    final problemi = problemiDelPiano(piano);
    if (problemi.isNotEmpty) {
      throw ErroreOperazione(problemi.first.messaggio, codice: 'CN021');
    }
    final lista = _versioni[pazienteId] ??= [];
    for (var i = 0; i < lista.length; i++) {
      if (lista[i].stato == StatoPiano.corrente) {
        lista[i] = PianoAlimentare(
          id: lista[i].id,
          versione: lista[i].versione,
          stato: StatoPiano.superato,
          dataInizio: lista[i].dataInizio,
          giorni: lista[i].giorni,
          creatoIl: lista[i].creatoIl,
        );
      }
    }
    salvataggi++;
    final nuova = PianoAlimentare(
      id: 'piano-$pazienteId-${lista.length + 1}',
      versione: lista.length + 1,
      stato: StatoPiano.corrente,
      dataInizio: piano.dataInizio,
      giorni: piano.giorni,
      creatoIl: DateTime.now(),
    );
    lista.add(nuova);
    notifyListeners();
    return nuova;
  }
}
